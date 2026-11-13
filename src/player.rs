//! Estado de reproducción expuesto a QML como singleton `Player`.
//!
//! De momento es una simulación: avanza una cola de ejemplo sin audio real.
//! El backend de audio (libmpv + yt-dlp) sustituirá a `tick` más adelante sin
//! cambiar las propiedades que consume la interfaz.

use std::pin::Pin;

use cxx_qt_lib::QString;

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    #[auto_cxx_name]
    extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qml_singleton]
        #[qproperty(bool, playing)]
        #[qproperty(f64, position)]
        #[qproperty(f64, duration)]
        #[qproperty(QString, title)]
        #[qproperty(QString, artist)]
        #[qproperty(i32, cover)]
        #[qproperty(i32, index)]
        type Player = super::PlayerRust;

        /// Alterna reproducción y pausa.
        #[qinvokable]
        fn toggle(self: Pin<&mut Player>);

        /// Salta a la pista siguiente de la cola.
        #[qinvokable]
        fn next(self: Pin<&mut Player>);

        /// Vuelve al inicio de la pista o a la anterior si acaba de empezar.
        #[qinvokable]
        fn previous(self: Pin<&mut Player>);

        /// Mueve la posición a `seconds`.
        #[qinvokable]
        fn seek(self: Pin<&mut Player>, seconds: f64);

        /// Avanza el reloj de reproducción `dt` segundos (simulación).
        #[qinvokable]
        fn tick(self: Pin<&mut Player>, dt: f64);
    }
}

struct Track {
    title: &'static str,
    artist: &'static str,
    duration: f64,
    cover: i32,
}

/// Cola de ejemplo hasta que exista el cliente de YouTube Music.
const QUEUE: &[Track] = &[
    Track { title: "Marea alta", artist: "Coral Lento", duration: 236.0, cover: 0 },
    Track { title: "Sal en la ventana", artist: "Coral Lento", duration: 201.0, cover: 0 },
    Track { title: "Faro apagado", artist: "Coral Lento", duration: 242.0, cover: 0 },
    Track { title: "Volver andando", artist: "Vera Luján", duration: 200.0, cover: 4 },
    Track { title: "Invernadero", artist: "Órbita Baja", duration: 220.0, cover: 1 },
];

pub struct PlayerRust {
    playing: bool,
    position: f64,
    duration: f64,
    title: QString,
    artist: QString,
    cover: i32,
    index: i32,
}

impl Default for PlayerRust {
    fn default() -> Self {
        let first = &QUEUE[0];
        Self {
            playing: true,
            position: 102.0,
            duration: first.duration,
            title: QString::from(first.title),
            artist: QString::from(first.artist),
            cover: first.cover,
            index: 0,
        }
    }
}

impl qobject::Player {
    fn toggle(mut self: Pin<&mut Self>) {
        let playing = !*self.playing();
        self.as_mut().set_playing(playing);
    }

    fn next(self: Pin<&mut Self>) {
        let next = (*self.index() + 1).rem_euclid(QUEUE.len() as i32);
        self.load(next);
    }

    fn previous(mut self: Pin<&mut Self>) {
        if *self.position() > 3.0 {
            self.as_mut().set_position(0.0);
        } else {
            let previous = (*self.index() - 1).rem_euclid(QUEUE.len() as i32);
            self.load(previous);
        }
    }

    fn seek(mut self: Pin<&mut Self>, seconds: f64) {
        let clamped = seconds.clamp(0.0, *self.duration());
        self.as_mut().set_position(clamped);
    }

    fn tick(mut self: Pin<&mut Self>, dt: f64) {
        if !*self.playing() {
            return;
        }
        let position = *self.position() + dt;
        if position >= *self.duration() {
            self.next();
        } else {
            self.as_mut().set_position(position);
        }
    }

    fn load(mut self: Pin<&mut Self>, index: i32) {
        let track = &QUEUE[index as usize];
        self.as_mut().set_index(index);
        self.as_mut().set_title(QString::from(track.title));
        self.as_mut().set_artist(QString::from(track.artist));
        self.as_mut().set_cover(track.cover);
        self.as_mut().set_duration(track.duration);
        self.as_mut().set_position(0.0);
    }
}
