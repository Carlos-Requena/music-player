// Cierre ordenado ante SIGTERM, SIGINT y SIGHUP (`kill <pid>`, Ctrl+C, cerrar la terminal).
//
// Sin esto, la señal mata la app sin destruir el `Player` y su `Mpv` (cuyo `Drop` cierra el
// proceso de mpv): mpv sigue vivo, huérfano y ocupando memoria. Con esto, la señal pide a Qt
// que salga de su bucle (`QCoreApplication::quit`), igual que al cerrar la ventana.
//
// Un manejador de señales solo puede llamar a funciones seguras en ese contexto (`write`), así
// que escribe un byte en un par de sockets («self-pipe») y un `QSocketNotifier` lo lee en el
// hilo de Qt. `SA_RESETHAND`: una segunda señal, si el cierre se atasca, mata la app como antes.

#include <QtCore/QCoreApplication>
#include <QtCore/QSocketNotifier>

#include <csignal>
#include <cstdio>
#include <fcntl.h>
#include <sys/socket.h>
#include <unistd.h>

namespace {

int signalSockets[2] = {-1, -1};

void onSignal(int)
{
    const char byte = 1;
    // El resultado no importa: si el socket está lleno, ya hay un aviso pendiente.
    [[maybe_unused]] const ssize_t written = ::write(signalSockets[0], &byte, 1);
}

} // namespace

// Se llama desde Rust con la `QGuiApplication` ya creada y antes de `exec()`.
extern "C" void musicplayer_handle_signals()
{
    if (::socketpair(AF_UNIX, SOCK_STREAM, 0, signalSockets) != 0) {
        std::perror("señales: socketpair");
        return;
    }
    for (int fd : signalSockets) {
        ::fcntl(fd, F_SETFD, FD_CLOEXEC); // que no lo hereden mpv ni yt-dlp
        ::fcntl(fd, F_SETFL, ::fcntl(fd, F_GETFL) | O_NONBLOCK);
    }

    auto *notifier = new QSocketNotifier(signalSockets[1], QSocketNotifier::Read, QCoreApplication::instance());
    QObject::connect(notifier, &QSocketNotifier::activated, notifier, [notifier]() {
        notifier->setEnabled(false);
        char buffer[16];
        while (::read(signalSockets[1], buffer, sizeof buffer) > 0) {
        }
        QCoreApplication::quit();
    });

    struct sigaction action = {};
    action.sa_handler = onSignal;
    sigemptyset(&action.sa_mask);
    action.sa_flags = SA_RESTART | SA_RESETHAND;
    for (int signal : {SIGTERM, SIGINT, SIGHUP}) {
        if (::sigaction(signal, &action, nullptr) != 0)
            std::perror("señales: sigaction");
    }
}
