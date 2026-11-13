// Ventana de inicio de sesión de YouTube Music para Linux, con Qt WebEngine.
//
// Mismo funcionamiento que la de macOS (src/login_mac.mm): perfil privado (nada queda en
// disco), página de Google con vuelta a YouTube Music y, cuando la propia página dice que hay
// sesión (`ytcfg LOGGED_IN`), se escriben las cookies de youtube.com en formato Netscape con
// permisos 600. Si el paso de Google a YouTube no deja las cookies en youtube.com, se copian
// las de la cuenta de Google y se vuelve a abrir YouTube Music (una sola vez).
//
// Código de salida: 0 si se guardó la sesión, 1 si el usuario cerró la ventana.

#include <QtCore/QByteArray>
#include <QtCore/QMap>
#include <QtCore/QSet>
#include <QtCore/QTimer>
#include <QtCore/QUrl>
#include <QtCore/QVariant>
#include <QtNetwork/QNetworkCookie>
#include <QtWebEngineCore/QWebEngineCookieStore>
#include <QtWebEngineCore/QWebEnginePage>
#include <QtWebEngineCore/QWebEngineProfile>
#include <QtWebEngineWidgets/QWebEngineView>
#include <QtWidgets/QApplication>

#include <cstdio>
#include <utility>

#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

namespace {

// El enlace «Iniciar sesión» de music.youtube.com.
const char *const kSignInUrl =
    "https://accounts.google.com/ServiceLogin?ltmpl=music&service=youtube&passive=true&hl=es"
    "&continue=https%3A%2F%2Fwww.youtube.com%2Fsignin%3Faction_handle_signin%3Dtrue%26app%3Ddesktop"
    "%26hl%3Des%26next%3Dhttps%253A%252F%252Fmusic.youtube.com%252F";

bool isYouTube(const QString &domain)
{
    const QString bare = domain.startsWith(QLatin1Char('.')) ? domain.mid(1) : domain;
    return bare == QLatin1String("youtube.com") || bare.endsWith(QLatin1String(".youtube.com"));
}

// Línea de un archivo de cookies de Netscape (el formato que leen yt-dlp y el reproductor).
QByteArray netscapeLine(const QNetworkCookie &cookie)
{
    const QByteArray domain = cookie.domain().toUtf8();
    const qint64 expires = cookie.expirationDate().isValid() ? cookie.expirationDate().toSecsSinceEpoch() : 0;
    QByteArray line;
    if (cookie.isHttpOnly())
        line.append("#HttpOnly_");
    line.append(domain);
    line.append('\t');
    line.append(domain.startsWith('.') ? "TRUE" : "FALSE");
    line.append('\t');
    line.append(cookie.path().isEmpty() ? QByteArray("/") : cookie.path().toUtf8());
    line.append('\t');
    line.append(cookie.isSecure() ? "TRUE" : "FALSE");
    line.append('\t');
    line.append(QByteArray::number(expires));
    line.append('\t');
    line.append(cookie.name());
    line.append('\t');
    line.append(cookie.value());
    line.append('\n');
    return line;
}

bool writePrivate(const char *path, const QByteArray &data)
{
    const int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0600);
    if (fd < 0)
        return false;
    fchmod(fd, 0600);
    const bool ok = write(fd, data.constData(), static_cast<size_t>(data.size())) == data.size();
    close(fd);
    return ok;
}

QString cookieKey(const QNetworkCookie &cookie)
{
    return cookie.domain() + QLatin1Char('|') + cookie.path() + QLatin1Char('|') + QString::fromUtf8(cookie.name());
}

} // namespace

extern "C" int musicplayer_login_linux(const char *outPath)
{
    static int argc = 1;
    static char name[] = "musicplayer-login";
    static char *argv[] = {name, nullptr};
    QApplication app(argc, argv);

    // Sin nombre de almacenamiento: perfil privado, en memoria.
    //
    // El agente de usuario NO se toca. Hacerse pasar por Chrome (quitando «QtWebEngine/x.y»)
    // es justo lo que delata la ventana: el motor sigue enviando sus cabeceras de cliente
    // (`Sec-CH-UA: "Chromium"`, sin «Google Chrome») y Google, al ver la contradicción, responde
    // «Este navegador o esta aplicación pueden no ser seguros». Con la identidad real del motor
    // todo coincide (cabecera, `navigator.userAgent` y cabeceras de cliente).
    QWebEngineProfile profile;

    QMap<QString, QNetworkCookie> jar;
    QWebEngineCookieStore *store = profile.cookieStore();
    QObject::connect(store, &QWebEngineCookieStore::cookieAdded, &app,
                     [&jar](const QNetworkCookie &cookie) { jar.insert(cookieKey(cookie), cookie); });
    QObject::connect(store, &QWebEngineCookieStore::cookieRemoved, &app,
                     [&jar](const QNetworkCookie &cookie) { jar.remove(cookieKey(cookie)); });
    store->loadAllCookies();

    QWebEnginePage page(&profile);
    QWebEngineView view;
    view.setPage(&page);
    view.resize(480, 720);
    view.setMinimumSize(380, 520);
    view.setWindowTitle(QStringLiteral("Iniciar sesión en YouTube Music"));

    int result = 1;
    bool finished = false;
    bool copied = false;

    const auto save = [&]() -> bool {
        QByteArray text("# Netscape HTTP Cookie File\n");
        bool session = false;
        QStringList names;
        for (const QNetworkCookie &cookie : std::as_const(jar)) {
            if (!isYouTube(cookie.domain()))
                continue;
            if (cookie.name() == "SAPISID" || cookie.name() == "__Secure-3PAPISID")
                session = true;
            text.append(netscapeLine(cookie));
            names << QString::fromUtf8(cookie.name());
        }
        // Solo nombres, nunca valores.
        fprintf(stderr, "inicio de sesión: %lld cookies de youtube.com (%s)\n", static_cast<long long>(names.size()),
                names.join(QStringLiteral(", ")).toUtf8().constData());
        return session && writePrivate(outPath, text);
    };

    // El paso de Google a YouTube no dejó la sesión en youtube.com: se copian las cookies de
    // la cuenta de Google y se vuelve a abrir YouTube Music.
    const auto copyGoogleSession = [&]() {
        if (copied)
            return;
        static const QSet<QByteArray> account = {"SID", "HSID", "SSID", "APISID", "SAPISID", "__Secure-1PSID",
                                                 "__Secure-3PSID", "__Secure-1PAPISID", "__Secure-3PAPISID",
                                                 "__Secure-1PSIDTS", "__Secure-3PSIDTS"};
        QList<QNetworkCookie> google;
        bool session = false;
        for (const QNetworkCookie &cookie : std::as_const(jar)) {
            if (cookie.domain() == QLatin1String(".google.com") && account.contains(cookie.name())) {
                session = session || cookie.name() == "SAPISID";
                google << cookie;
            }
        }
        if (!session)
            return;
        copied = true;
        fprintf(stderr, "inicio de sesión: copiando %lld cookies de la cuenta de Google a youtube.com\n",
                static_cast<long long>(google.size()));
        for (QNetworkCookie cookie : google) {
            cookie.setDomain(QStringLiteral(".youtube.com"));
            store->setCookie(cookie, QUrl(QStringLiteral("https://www.youtube.com/")));
        }
        QTimer::singleShot(400, &page, [&page]() { page.load(QUrl(QStringLiteral("https://music.youtube.com/"))); });
    };

    QObject::connect(&page, &QWebEnginePage::loadFinished, &app, [&](bool) {
        if (finished)
            return;
        const QString host = page.url().host();
        if (!isYouTube(host))
            return;
        if (host != QLatin1String("music.youtube.com")) {
            fprintf(stderr, "inicio de sesión: página %s%s\n", host.toUtf8().constData(),
                    page.url().path().toUtf8().constData());
            copyGoogleSession();
            return;
        }
        page.runJavaScript(QStringLiteral("!!(window.ytcfg && ytcfg.get('LOGGED_IN'))"), 0,
                           [&](const QVariant &value) {
                               if (finished)
                                   return;
                               fprintf(stderr, "inicio de sesión: YouTube Music %s\n",
                                       value.toBool() ? "con sesión" : "sin sesión");
                               if (!value.toBool()) {
                                   copyGoogleSession();
                                   return;
                               }
                               // Las cookies llegan al almacén un instante después de cargar.
                               QTimer::singleShot(300, &app, [&]() {
                                   if (finished || !save())
                                       return;
                                   finished = true;
                                   result = 0;
                                   view.hide();
                                   app.quit();
                               });
                           });
    });

    page.load(QUrl(QString::fromLatin1(kSignInUrl)));
    view.show();
    app.exec();
    return result;
}
