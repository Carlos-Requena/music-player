// Ajustes de las ventanas de Qt Quick que QML no expone.
//
// Al minimizar u ocultar una ventana se liberan su grafo de escena y sus recursos gráficos:
// el controlador de macOS reserva ~100 MB para una ventana que se redibuja y, sin esto, los
// mantiene aunque nadie la vea. Al volver a mostrarse, Qt los recrea (unos milisegundos).

#include <QtCore/QObject>
#include <QtCore/QUrl>
#include <QtNetwork/QNetworkProxy>
#include <QtNetwork/QNetworkProxyFactory>
#include <QtGui/QGuiApplication>
#include <QtGui/QWindow>
#include <QtQuick/QQuickWindow>

namespace {

void tune(QQuickWindow *window)
{
    if (window->property("musicplayerTuned").toBool())
        return;
    window->setProperty("musicplayerTuned", true);
    window->setPersistentGraphics(false);
    window->setPersistentSceneGraph(false);
    QObject::connect(window, &QWindow::visibilityChanged, window, [window](QWindow::Visibility visibility) {
        if (visibility == QWindow::Minimized || visibility == QWindow::Hidden)
            window->releaseResources();
    });
}

} // namespace

// Red de Qt (carátulas y demás imágenes). Por defecto Qt consulta el proxy del sistema; si
// éste usa detección automática (WPAD) con un servidor que no existe, macOS falla en cada
// descarga («NSURLErrorDomain error -1003») y la retrasa. Se ignora el del sistema y solo se
// usa un proxy si se indica con HTTPS_PROXY o HTTP_PROXY, como hace el núcleo en Rust.
extern "C" void musicplayer_configure_network()
{
    QNetworkProxyFactory::setUseSystemConfiguration(false);
    for (const char *name : {"HTTPS_PROXY", "https_proxy", "HTTP_PROXY", "http_proxy"}) {
        const QByteArray value = qgetenv(name);
        if (value.isEmpty())
            continue;
        const QUrl url(QString::fromUtf8(value));
        if (url.isValid() && !url.host().isEmpty()) {
            QNetworkProxy::setApplicationProxy(QNetworkProxy(QNetworkProxy::HttpProxy, url.host(), url.port(8080),
                                                             url.userName(), url.password()));
            return;
        }
    }
    QNetworkProxy::setApplicationProxy(QNetworkProxy::NoProxy);
}

// Se llama desde Rust tras cargar la interfaz (y cada vez que se crea una ventana nueva).
extern "C" void musicplayer_tune_windows()
{
    const auto windows = QGuiApplication::topLevelWindows();
    for (QWindow *window : windows) {
        if (auto *quick = qobject_cast<QQuickWindow *>(window))
            tune(quick);
    }
}
