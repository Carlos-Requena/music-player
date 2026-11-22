//! Tuberías con nombre de Windows (`\\.\pipe\…`), por donde se habla con mpv y con Discord.
//!
//! Se abren en modo «overlapped»: con un manejador síncrono, Windows pone en fila las
//! operaciones del mismo archivo y una lectura que espera (el hilo que escucha a mpv) bloquea
//! cualquier escritura (las órdenes) hasta que llega algo. Así, cada lectura y cada escritura
//! espera solo a sí misma, y `Clone` da otro extremo del mismo manejador para leer en un hilo y
//! escribir en otro, como `UnixStream::try_clone`.

use std::{
    io,
    os::windows::{
        ffi::OsStrExt,
        io::{AsRawHandle, FromRawHandle, OwnedHandle},
    },
    path::Path,
    ptr,
    sync::Arc,
    time::Duration,
};

use windows_sys::Win32::{
    Foundation::{
        GetLastError, ERROR_BROKEN_PIPE, ERROR_IO_PENDING, GENERIC_READ, GENERIC_WRITE, HANDLE,
        INVALID_HANDLE_VALUE, WAIT_OBJECT_0,
    },
    Storage::FileSystem::{CreateFileW, ReadFile, WriteFile, FILE_FLAG_OVERLAPPED, OPEN_EXISTING},
    System::{
        Threading::{CreateEventW, WaitForSingleObject, INFINITE},
        IO::{CancelIoEx, GetOverlappedResult, OVERLAPPED},
    },
};

#[derive(Clone)]
pub struct Tuberia {
    handle: Arc<OwnedHandle>,
    /// Tiempo máximo de cada lectura o escritura (`None`: sin límite).
    timeout: Option<Duration>,
}

impl Tuberia {
    /// Se conecta a una tubería que ya existe; falla si el servidor aún no la ha creado.
    pub fn open(path: &Path) -> io::Result<Self> {
        let wide: Vec<u16> = path.as_os_str().encode_wide().chain(Some(0)).collect();
        // SAFETY: `wide` es una cadena terminada en cero que vive durante toda la llamada.
        let handle = unsafe {
            CreateFileW(
                wide.as_ptr(),
                GENERIC_READ | GENERIC_WRITE,
                0,
                ptr::null(),
                OPEN_EXISTING,
                FILE_FLAG_OVERLAPPED,
                ptr::null_mut(),
            )
        };
        if handle == INVALID_HANDLE_VALUE {
            return Err(io::Error::last_os_error());
        }
        // SAFETY: manejador recién abierto y válido; pasa a ser de `OwnedHandle`, que lo cierra.
        let handle = unsafe { OwnedHandle::from_raw_handle(handle as _) };
        Ok(Self { handle: Arc::new(handle), timeout: None })
    }

    pub fn set_timeout(&mut self, timeout: Option<Duration>) {
        self.timeout = timeout;
    }

    /// Una lectura o escritura «overlapped» que se espera hasta que termina (o hasta el límite).
    fn io(&self, start: impl FnOnce(HANDLE, *mut OVERLAPPED) -> i32) -> io::Result<usize> {
        // SAFETY: crea un evento sin nombre; se comprueba el resultado.
        let event = unsafe { CreateEventW(ptr::null(), 1, 0, ptr::null()) };
        if event.is_null() {
            return Err(io::Error::last_os_error());
        }
        // SAFETY: evento recién creado; `OwnedHandle` lo cierra al salir.
        let event = unsafe { OwnedHandle::from_raw_handle(event as _) };
        // SAFETY: OVERLAPPED es una estructura C sin invariantes; a ceros es su valor inicial.
        let mut overlapped: OVERLAPPED = unsafe { std::mem::zeroed() };
        overlapped.hEvent = event.as_raw_handle() as HANDLE;
        let handle = self.handle.as_raw_handle() as HANDLE;

        if start(handle, &mut overlapped) == 0 {
            // SAFETY: sin argumentos.
            let error = unsafe { GetLastError() };
            if error == ERROR_BROKEN_PIPE {
                return Ok(0);
            }
            if error != ERROR_IO_PENDING {
                return Err(io::Error::from_raw_os_error(error as i32));
            }
        }
        let mut timed_out = false;
        if let Some(timeout) = self.timeout {
            let millis = timeout.as_millis().min(u128::from(INFINITE - 1)) as u32;
            // SAFETY: el evento es válido mientras vive `event`.
            if unsafe { WaitForSingleObject(overlapped.hEvent, millis) } != WAIT_OBJECT_0 {
                // SAFETY: cancela solo esta operación; después se espera a que acabe de verdad
                // (`overlapped` no puede liberarse mientras el sistema lo usa).
                unsafe { CancelIoEx(handle, &overlapped) };
                timed_out = true;
            }
        }
        let mut done = 0u32;
        // SAFETY: `overlapped` es el de la operación que se acaba de lanzar; se espera a que acabe.
        if unsafe { GetOverlappedResult(handle, &overlapped, &mut done, 1) } == 0 {
            let error = io::Error::last_os_error();
            if timed_out {
                return Err(io::Error::new(io::ErrorKind::TimedOut, "la tubería no respondió a tiempo"));
            }
            if error.raw_os_error() == Some(ERROR_BROKEN_PIPE as i32) {
                return Ok(0);
            }
            return Err(error);
        }
        Ok(done as usize)
    }
}

impl io::Read for Tuberia {
    fn read(&mut self, buf: &mut [u8]) -> io::Result<usize> {
        let len = buf.len().min(u32::MAX as usize) as u32;
        // SAFETY: `buf` vive y no se mueve hasta que `io` espera el final de la operación.
        self.io(|handle, overlapped| unsafe { ReadFile(handle, buf.as_mut_ptr(), len, ptr::null_mut(), overlapped) })
    }
}

impl io::Write for Tuberia {
    fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
        let len = buf.len().min(u32::MAX as usize) as u32;
        // SAFETY: igual que en `read`.
        self.io(|handle, overlapped| unsafe { WriteFile(handle, buf.as_ptr(), len, ptr::null_mut(), overlapped) })
    }

    fn flush(&mut self) -> io::Result<()> {
        Ok(())
    }
}

/// Mete el reproductor en un «job» que el sistema cierra al terminar el proceso: así mpv,
/// yt-dlp y ffmpeg mueren con él aunque se cierre a la fuerza (en Windows no hay señales que
/// recoger y los hijos se quedarían huérfanos).
pub fn kill_children_on_exit() {
    use windows_sys::Win32::System::{
        JobObjects::{
            AssignProcessToJobObject, CreateJobObjectW, JobObjectExtendedLimitInformation,
            SetInformationJobObject, JOBOBJECT_EXTENDED_LIMIT_INFORMATION, JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE,
        },
        Threading::GetCurrentProcess,
    };
    // SAFETY: llamadas sin punteros guardados; el «job» se deja abierto a propósito durante toda
    // la vida del proceso (al cerrarse su último manejador, el sistema termina a los hijos).
    unsafe {
        let job = CreateJobObjectW(ptr::null(), ptr::null());
        if job.is_null() {
            return;
        }
        let mut limits: JOBOBJECT_EXTENDED_LIMIT_INFORMATION = std::mem::zeroed();
        limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
        let size = std::mem::size_of::<JOBOBJECT_EXTENDED_LIMIT_INFORMATION>() as u32;
        let set = SetInformationJobObject(
            job,
            JobObjectExtendedLimitInformation,
            &limits as *const _ as *const std::ffi::c_void,
            size,
        );
        if set == 0 || AssignProcessToJobObject(job, GetCurrentProcess()) == 0 {
            eprintln!("procesos: no se pudo atar mpv y yt-dlp al reproductor: {}", io::Error::last_os_error());
        }
    }
}
