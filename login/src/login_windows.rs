//! Ventana de inicio de sesión de YouTube Music para Windows, con WebView2 (el motor de Edge
//! que trae el sistema, sin nada que instalar).
//!
//! Mismo protocolo que las de macOS y Linux: al volver a `music.youtube.com` con la sesión
//! iniciada (`ytcfg LOGGED_IN`), escribe las cookies de youtube.com en formato Netscape y sale
//! con 0; si se cierra la ventana, con 1.
//!
//! - **Nitidez:** el proceso se declara «consciente del DPI por monitor» antes de crear la
//!   ventana; sin eso Windows la dibujaría a 96 ppp y la ampliaría, borrosa.
//! - **Nada en disco:** el navegador va en modo InPrivate (las cookies viven solo en memoria).
//!   La carpeta de datos de WebView2 (`%LOCALAPPDATA%\musicplayer\webview2`) solo guarda la
//!   caché del motor.
//! - **Agente de usuario sin tocar:** el de WebView2 es el de Edge, con sus `Sec-CH-UA`
//!   coherentes (ver la ficha de sesión).

use std::{cell::RefCell, fs, path::PathBuf, sync::mpsc};

use webview2_com::{
    CoTaskMemPWSTR, CreateCoreWebView2ControllerCompletedHandler, CreateCoreWebView2EnvironmentCompletedHandler,
    ExecuteScriptCompletedHandler, GetCookiesCompletedHandler,
    Microsoft::Web::WebView2::Win32::{
        CreateCoreWebView2EnvironmentWithOptions, ICoreWebView2, ICoreWebView2Controller, ICoreWebView2CookieList,
        ICoreWebView2Environment, ICoreWebView2Environment10, ICoreWebView2_2,
    },
    NavigationCompletedEventHandler,
};
use windows::{
    core::{w, Interface, HSTRING, PCWSTR, PWSTR},
    Win32::{
        Foundation::{E_POINTER, HWND, LPARAM, LRESULT, RECT, WPARAM},
        System::{
            Com::{CoInitializeEx, COINIT_APARTMENTTHREADED},
            LibraryLoader::GetModuleHandleW,
        },
        UI::{
            HiDpi::{GetDpiForSystem, SetProcessDpiAwarenessContext, DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2},
            WindowsAndMessaging::{
                CreateWindowExW, DefWindowProcW, DestroyWindow, DispatchMessageW, GetClientRect, GetMessageW,
                LoadCursorW, PostQuitMessage, RegisterClassW, ShowWindow, TranslateMessage, CW_USEDEFAULT, IDC_ARROW,
                MSG, SW_SHOW, WINDOW_EX_STYLE, WM_CLOSE, WM_DESTROY, WM_SIZE, WNDCLASSW, WS_OVERLAPPEDWINDOW,
            },
        },
    },
};

/// El enlace «Iniciar sesión» de music.youtube.com (el mismo que en macOS).
const SIGN_IN_URL: &str = "https://accounts.google.com/ServiceLogin?ltmpl=music&service=youtube&passive=true&hl=es\
    &continue=https%3A%2F%2Fwww.youtube.com%2Fsignin%3Faction_handle_signin%3Dtrue%26app%3Ddesktop\
    %26hl%3Des%26next%3Dhttps%253A%252F%252Fmusic.youtube.com%252F";

struct State {
    out_path: PathBuf,
    window: HWND,
    controller: Option<ICoreWebView2Controller>,
    webview: Option<ICoreWebView2>,
    /// Ya se guardó la sesión (o se está guardando): no se vuelve a comprobar.
    finished: bool,
    result: i32,
}

thread_local! {
    static STATE: RefCell<Option<State>> = const { RefCell::new(None) };
}

fn with_state<T>(f: impl FnOnce(&mut State) -> T) -> Option<T> {
    STATE.with(|state| state.borrow_mut().as_mut().map(f))
}

fn fail(message: &str) -> i32 {
    eprintln!("inicio de sesión: {message}");
    2
}

/// Abre la ventana y espera a que termine. Devuelve el código de salida del proceso.
pub fn run(out_path: &str) -> i32 {
    // SAFETY: llamadas de inicio del proceso, en su hilo principal, antes de crear ventanas.
    unsafe {
        if CoInitializeEx(None, COINIT_APARTMENTTHREADED).is_err() {
            return fail("no se pudo iniciar COM");
        }
        let _ = SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    }
    let Some(window) = create_window() else { return fail("no se pudo crear la ventana") };
    STATE.with(|state| {
        *state.borrow_mut() = Some(State {
            out_path: PathBuf::from(out_path),
            window,
            controller: None,
            webview: None,
            finished: false,
            result: 1,
        })
    });
    if let Err(error) = open_webview(window) {
        // Sin el motor de WebView2 (Windows sin actualizar): el reproductor ofrece importar.
        // SAFETY: ventana creada por este hilo.
        unsafe {
            let _ = DestroyWindow(window);
        }
        return fail(&format!("no se pudo abrir WebView2: {error}"));
    }
    // SAFETY: ventana válida, de este hilo.
    unsafe {
        let _ = ShowWindow(window, SW_SHOW);
    }

    let mut message = MSG::default();
    // SAFETY: bucle de mensajes estándar de Win32 en el hilo que creó la ventana.
    unsafe {
        while GetMessageW(&mut message, None, 0, 0).as_bool() {
            let _ = TranslateMessage(&message);
            DispatchMessageW(&message);
        }
    }
    let result = with_state(|state| state.result).unwrap_or(1);
    // Cierra el navegador antes de salir (libera sus procesos).
    if let Some(controller) = with_state(|state| state.controller.take()).flatten() {
        // SAFETY: controlador creado en este hilo.
        let _ = unsafe { controller.Close() };
    }
    result
}

fn create_window() -> Option<HWND> {
    // SAFETY: registro y creación de una ventana Win32 con una clase propia.
    unsafe {
        let instance = GetModuleHandleW(None).ok()?;
        let class = WNDCLASSW {
            lpfnWndProc: Some(window_proc),
            hInstance: instance.into(),
            hCursor: LoadCursorW(None, IDC_ARROW).unwrap_or_default(),
            lpszClassName: w!("MusicplayerLogin"),
            ..Default::default()
        };
        RegisterClassW(&class);
        // 480 × 720 a 100 %, escalado al DPI del sistema.
        let scale = GetDpiForSystem() as i32;
        let (width, height) = (480 * scale / 96, 720 * scale / 96);
        CreateWindowExW(
            WINDOW_EX_STYLE::default(),
            w!("MusicplayerLogin"),
            w!("Iniciar sesión en YouTube Music"),
            WS_OVERLAPPEDWINDOW,
            CW_USEDEFAULT,
            CW_USEDEFAULT,
            width,
            height,
            None,
            None,
            Some(instance.into()),
            None,
        )
        .ok()
    }
}

extern "system" fn window_proc(window: HWND, message: u32, wparam: WPARAM, lparam: LPARAM) -> LRESULT {
    match message {
        WM_SIZE => {
            resize(window);
            LRESULT(0)
        }
        WM_CLOSE => {
            // SAFETY: ventana de este hilo.
            unsafe {
                let _ = DestroyWindow(window);
            }
            LRESULT(0)
        }
        WM_DESTROY => {
            // SAFETY: sin argumentos que guardar.
            unsafe { PostQuitMessage(0) };
            LRESULT(0)
        }
        // SAFETY: lo demás, el comportamiento por defecto.
        _ => unsafe { DefWindowProcW(window, message, wparam, lparam) },
    }
}

/// El navegador ocupa toda la ventana.
fn resize(window: HWND) {
    let Some(Some(controller)) = with_state(|state| state.controller.clone()) else { return };
    let mut rect = RECT::default();
    // SAFETY: ventana y controlador válidos, de este hilo.
    unsafe {
        let _ = GetClientRect(window, &mut rect);
        let _ = controller.SetBounds(rect);
    }
}

fn data_folder() -> Option<HSTRING> {
    let base = std::env::var_os("LOCALAPPDATA").map(PathBuf::from).or_else(|| Some(std::env::temp_dir()))?;
    let folder = base.join("musicplayer").join("webview2");
    let _ = fs::create_dir_all(&folder);
    Some(HSTRING::from(folder.as_os_str()))
}

fn open_webview(window: HWND) -> webview2_com::Result<()> {
    let folder = data_folder().unwrap_or_default();
    let environment = {
        let (tx, rx) = mpsc::channel();
        CreateCoreWebView2EnvironmentCompletedHandler::wait_for_async_operation(
            Box::new(move |handler| unsafe {
                CreateCoreWebView2EnvironmentWithOptions(PCWSTR::null(), &folder, None, &handler)
                    .map_err(webview2_com::Error::WindowsError)
            }),
            Box::new(move |error, environment: Option<ICoreWebView2Environment>| {
                error?;
                let _ = tx.send(environment.ok_or_else(|| windows::core::Error::from(E_POINTER)));
                Ok(())
            }),
        )?;
        rx.recv().map_err(|_| webview2_com::Error::SendError)??
    };

    let controller = {
        let (tx, rx) = mpsc::channel();
        CreateCoreWebView2ControllerCompletedHandler::wait_for_async_operation(
            Box::new(move |handler| unsafe {
                // InPrivate: las cookies no se escriben en disco. Con un WebView2 antiguo que no
                // lo admite, un navegador normal.
                match environment.cast::<ICoreWebView2Environment10>() {
                    Ok(environment) => {
                        let options = environment.CreateCoreWebView2ControllerOptions()?;
                        options.SetIsInPrivateModeEnabled(true)?;
                        environment.CreateCoreWebView2ControllerWithOptions(window, &options, &handler)
                    }
                    Err(_) => environment.CreateCoreWebView2Controller(window, &handler),
                }
                .map_err(webview2_com::Error::WindowsError)
            }),
            Box::new(move |error, controller: Option<ICoreWebView2Controller>| {
                error?;
                let _ = tx.send(controller.ok_or_else(|| windows::core::Error::from(E_POINTER)));
                Ok(())
            }),
        )?;
        rx.recv().map_err(|_| webview2_com::Error::SendError)??
    };

    // SAFETY: controlador recién creado en este hilo.
    let webview = unsafe {
        controller.SetIsVisible(true)?;
        controller.CoreWebView2()?
    };
    with_state(|state| {
        state.controller = Some(controller);
        state.webview = Some(webview.clone());
    });
    resize(window);

    let handler = NavigationCompletedEventHandler::create(Box::new(|_, _| {
        check();
        Ok(())
    }));
    let mut token = 0;
    // Depuración: MUSICPLAYER_LOGIN_URL cambia la página inicial.
    let start = std::env::var("MUSICPLAYER_LOGIN_URL").unwrap_or_else(|_| SIGN_IN_URL.to_owned());
    // SAFETY: el manejador y la URL viven durante cada llamada.
    unsafe {
        webview.add_NavigationCompleted(&handler, &mut token)?;
        webview.Navigate(&HSTRING::from(start))?;
    }
    Ok(())
}

/// Dirección de la página actual.
fn current_url(webview: &ICoreWebView2) -> String {
    let mut source = PWSTR::null();
    // SAFETY: WebView2 reserva la cadena con CoTaskMemAlloc; `CoTaskMemPWSTR` la libera.
    unsafe {
        if webview.Source(&mut source).is_err() {
            return String::new();
        }
    }
    CoTaskMemPWSTR::from(source).to_string()
}

fn host(url: &str) -> &str {
    let rest = url.split_once("://").map_or(url, |(_, rest)| rest);
    rest.split(['/', '?', '#']).next().unwrap_or_default()
}

/// Al terminar de cargar cada página (nunca a mitad de las redirecciones de Google): en
/// music.youtube.com se pregunta a la propia página si hay sesión y, si la hay, se guarda.
fn check() {
    let Some(Some(webview)) = with_state(|state| if state.finished { None } else { state.webview.clone() }) else {
        return;
    };
    let url = current_url(&webview);
    let host = host(&url);
    if host != "music.youtube.com" {
        if host.ends_with("youtube.com") {
            eprintln!("inicio de sesión: página {host}");
        }
        return;
    }
    let handler = ExecuteScriptCompletedHandler::create(Box::new(|error, value: String| {
        error?;
        let logged = value.trim() == "true";
        eprintln!("inicio de sesión: YouTube Music {}", if logged { "con sesión" } else { "sin sesión" });
        if logged {
            save();
        }
        Ok(())
    }));
    // SAFETY: el manejador vive durante la llamada; WebView2 se queda su propia referencia.
    unsafe {
        let _ = webview.ExecuteScript(w!("!!(window.ytcfg && ytcfg.get('LOGGED_IN'))"), &handler);
    }
}

fn is_youtube(domain: &str) -> bool {
    let bare = domain.strip_prefix('.').unwrap_or(domain);
    bare == "youtube.com" || bare.ends_with(".youtube.com")
}

fn take(get: impl FnOnce(&mut PWSTR) -> windows::core::Result<()>) -> String {
    let mut text = PWSTR::null();
    if get(&mut text).is_err() {
        return String::new();
    }
    CoTaskMemPWSTR::from(text).to_string()
}

/// Archivo de cookies de Netscape con las de youtube.com (el formato que leen yt-dlp y el
/// reproductor). Devuelve también sus nombres, para el registro (nunca los valores).
fn netscape(list: &ICoreWebView2CookieList) -> windows::core::Result<(String, Vec<String>)> {
    let mut text = String::from("# Netscape HTTP Cookie File\n");
    let mut names = Vec::new();
    let mut count = 0u32;
    // SAFETY: lista válida que entrega WebView2; cada cadena se libera con `take`.
    unsafe {
        list.Count(&mut count)?;
        for index in 0..count {
            let cookie = list.GetValueAtIndex(index)?;
            let domain = take(|out| cookie.Domain(out));
            if !is_youtube(&domain) {
                continue;
            }
            let name = take(|out| cookie.Name(out));
            let value = take(|out| cookie.Value(out));
            let path = take(|out| cookie.Path(out));
            let mut expires = 0f64;
            let _ = cookie.Expires(&mut expires);
            let mut flag = Default::default();
            let http_only = cookie.IsHttpOnly(&mut flag).is_ok() && flag.as_bool();
            let secure = cookie.IsSecure(&mut flag).is_ok() && flag.as_bool();
            text.push_str(&format!(
                "{}{domain}\t{}\t{}\t{}\t{}\t{name}\t{value}\n",
                if http_only { "#HttpOnly_" } else { "" },
                if domain.starts_with('.') { "TRUE" } else { "FALSE" },
                if path.is_empty() { "/" } else { path.as_str() },
                if secure { "TRUE" } else { "FALSE" },
                // -1: cookie de sesión.
                if expires > 0.0 { expires as i64 } else { 0 },
            ));
            names.push(name);
        }
    }
    Ok((text, names))
}

fn save() {
    let Some(Some(webview)) = with_state(|state| {
        if state.finished {
            return None;
        }
        state.finished = true;
        state.webview.clone()
    }) else {
        return;
    };
    let manager = webview.cast::<ICoreWebView2_2>().and_then(|webview| unsafe { webview.CookieManager() });
    let manager = match manager {
        Ok(manager) => manager,
        Err(error) => {
            eprintln!("inicio de sesión: WebView2 sin gestor de cookies: {error}");
            with_state(|state| state.finished = false);
            return;
        }
    };
    let handler = GetCookiesCompletedHandler::create(Box::new(|error, list: Option<ICoreWebView2CookieList>| {
        error?;
        let list = list.ok_or_else(|| windows::core::Error::from(E_POINTER))?;
        let (text, names) = netscape(&list)?;
        eprintln!("inicio de sesión: {} cookies de youtube.com ({})", names.len(), names.join(", "));
        let Some((path, window)) = with_state(|state| (state.out_path.clone(), state.window)) else { return Ok(()) };
        match fs::write(&path, text) {
            Ok(()) => {
                with_state(|state| state.result = 0);
                // SAFETY: ventana de este hilo; cierra el bucle de mensajes.
                unsafe {
                    let _ = DestroyWindow(window);
                }
            }
            Err(error) => {
                eprintln!("inicio de sesión: no se pudo guardar en {}: {error}", path.display());
                with_state(|state| state.finished = false);
            }
        }
        Ok(())
    }));
    // SAFETY: el manejador vive durante la llamada; WebView2 se queda su propia referencia.
    unsafe {
        let _ = manager.GetCookies(w!("https://music.youtube.com"), &handler);
    }
}

#[cfg(test)]
mod tests {
    use super::{host, is_youtube};

    #[test]
    fn reconoce_el_host() {
        assert_eq!(host("https://music.youtube.com/?cbrd=1"), "music.youtube.com");
        assert_eq!(host("https://accounts.google.com/ServiceLogin"), "accounts.google.com");
        assert!(is_youtube(".youtube.com") && is_youtube("music.youtube.com") && !is_youtube("notyoutube.com"));
    }
}
