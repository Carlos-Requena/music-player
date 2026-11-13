// Ventana de inicio de sesión de YouTube Music (macOS).
//
// Se ejecuta en un proceso aparte (`musicplayer --login <archivo>`), así el motor web no
// ocupa memoria en el reproductor. Usa WebKit del sistema (el motor de Safari, sin
// dependencias) con un almacén de datos privado: no queda nada en disco salvo el archivo de
// cookies de youtube.com que se escribe al terminar, legible solo por el usuario.
//
// Código de salida: 0 si se guardó la sesión, 1 si el usuario cerró la ventana.

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <objc/message.h>

#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

// El enlace «Iniciar sesión» de music.youtube.com: tras entrar en Google vuelve a YouTube
// Music, que es cuando ya están puestas las cookies de youtube.com.
static NSString *const kSignInUrl =
    @"https://accounts.google.com/ServiceLogin?ltmpl=music&service=youtube&passive=true&hl=es"
    @"&continue=https%3A%2F%2Fwww.youtube.com%2Fsignin%3Faction_handle_signin%3Dtrue%26app%3Ddesktop"
    @"%26hl%3Des%26next%3Dhttps%253A%252F%252Fmusic.youtube.com%252F";

static BOOL isYouTube(NSString *domain)
{
    NSString *bare = [domain hasPrefix:@"."] ? [domain substringFromIndex:1] : domain;
    return [bare isEqualToString:@"youtube.com"] || [bare hasSuffix:@".youtube.com"];
}

// Línea de un archivo de cookies de Netscape (el formato que leen yt-dlp y el reproductor).
static NSString *netscapeLine(NSHTTPCookie *cookie)
{
    NSString *domain = cookie.domain;
    long long expires = cookie.expiresDate ? (long long)cookie.expiresDate.timeIntervalSince1970 : 0;
    return [NSString stringWithFormat:@"%@%@\t%@\t%@\t%@\t%lld\t%@\t%@\n",
                                      cookie.isHTTPOnly ? @"#HttpOnly_" : @"", domain,
                                      [domain hasPrefix:@"."] ? @"TRUE" : @"FALSE", cookie.path ?: @"/",
                                      cookie.isSecure ? @"TRUE" : @"FALSE", expires, cookie.name, cookie.value];
}

// Versión de Safari instalada, para que Google vea un Safari normal y no «un navegador
// embebido» (lo que provoca «Este navegador o esta aplicación pueden no ser seguros»).
static NSString *safariVersion()
{
    NSBundle *safari = [NSBundle bundleWithPath:@"/Applications/Safari.app"];
    NSString *version = safari.infoDictionary[@"CFBundleShortVersionString"];
    return version.length > 0 ? version : @"26.0";
}

@interface MPLogin : NSObject <NSWindowDelegate, WKNavigationDelegate, WKUIDelegate>
@property(nonatomic, copy) NSString *outPath;
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) WKWebView *web;
@property(nonatomic) int result;
@property(nonatomic) BOOL finished;
@property(nonatomic) BOOL copied;
@property(nonatomic) BOOL copying;
@end

@implementation MPLogin

- (void)open
{
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.websiteDataStore = [WKWebsiteDataStore nonPersistentDataStore];
    // La prevención de rastreo de WebKit descarta cookies en cadenas de redirecciones entre
    // dominios, justo como pasa Google la sesión a youtube.com. Ajuste privado de WebKit: si
    // no existe, se recurre a copiar las cookies (`check`).
    SEL itp = NSSelectorFromString(@"_setResourceLoadStatisticsEnabled:");
    if ([config.websiteDataStore respondsToSelector:itp])
        ((void (*)(id, SEL, BOOL))objc_msgSend)(config.websiteDataStore, itp, NO);
    config.applicationNameForUserAgent = [NSString stringWithFormat:@"Version/%@ Safari/605.1.15", safariVersion()];
    
    NSRect frame = NSMakeRect(0, 0, 480, 720);
    self.window = [[NSWindow alloc]
        initWithContentRect:frame
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
                               | NSWindowStyleMaskMiniaturizable
                    backing:NSBackingStoreBuffered
                      defer:NO];
    self.window.title = @"Iniciar sesión en YouTube Music";
    self.window.releasedWhenClosed = NO;
    self.window.delegate = self;
    self.window.minSize = NSMakeSize(380, 520);

    self.web = [[WKWebView alloc] initWithFrame:frame configuration:config];
    self.web.navigationDelegate = self;
    self.web.UIDelegate = self;
    self.web.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.window.contentView = self.web;

    // Depuración: MUSICPLAYER_LOGIN_URL cambia la página inicial.
    const char *start = getenv("MUSICPLAYER_LOGIN_URL");
    NSString *url = start ? [NSString stringWithUTF8String:start] : kSignInUrl;
    [self.web loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

// Cookies de la cuenta de Google que YouTube copia a youtube.com al iniciar sesión.
static NSSet<NSString *> *accountCookies()
{
    return [NSSet setWithArray:@[ @"SID", @"HSID", @"SSID", @"APISID", @"SAPISID", @"__Secure-1PSID",
                                  @"__Secure-3PSID", @"__Secure-1PAPISID", @"__Secure-3PAPISID",
                                  @"__Secure-1PSIDTS", @"__Secure-3PSIDTS" ]];
}

// Se comprueba al terminar de cargar cada página (nunca a mitad de la cadena de
// redirecciones de Google, que pone las cookies poco a poco):
// - En music.youtube.com se pregunta a la propia página si hay sesión (`ytcfg LOGGED_IN`).
//   Si la hay, se guardan las cookies de youtube.com y se cierra la ventana.
// - Si YouTube no la tiene (acabó en /oops, la página de las teles, o YouTube Music sin
//   sesión) pero Google sí, se copian a youtube.com las cookies de la cuenta de Google y se
//   vuelve a abrir YouTube Music. Solo una vez.
- (void)check
{
    NSString *host = self.web.URL.host ?: @"";
    if (self.finished || self.copying || !isYouTube(host))
        return;
    if (![host isEqualToString:@"music.youtube.com"]) {
        fprintf(stderr, "inicio de sesión: página %s%s\n", host.UTF8String, self.web.URL.path.UTF8String);
        [self copyGoogleSession];
        return;
    }
    [self.web evaluateJavaScript:@"!!(window.ytcfg && ytcfg.get('LOGGED_IN'))"
               completionHandler:^(id value, NSError *) {
                   if (self.finished)
                       return;
                   BOOL logged = [value respondsToSelector:@selector(boolValue)] && [value boolValue];
                   fprintf(stderr, "inicio de sesión: YouTube Music %s\n", logged ? "con sesión" : "sin sesión");
                   if (logged)
                       [self saveAndFinish];
                   else
                       [self copyGoogleSession];
               }];
}

- (void)saveAndFinish
{
    [self.web.configuration.websiteDataStore.httpCookieStore getAllCookies:^(NSArray<NSHTTPCookie *> *cookies) {
        if (self.finished)
            return;
        NSMutableString *text = [NSMutableString stringWithString:@"# Netscape HTTP Cookie File\n"];
        NSMutableArray<NSString *> *names = [NSMutableArray array];
        for (NSHTTPCookie *cookie in cookies) {
            if (!isYouTube(cookie.domain))
                continue;
            [text appendString:netscapeLine(cookie)];
            [names addObject:cookie.name];
        }
        // Solo nombres, nunca valores.
        fprintf(stderr, "inicio de sesión: %lu cookies de youtube.com (%s)\n", (unsigned long)names.count,
                [names componentsJoinedByString:@", "].UTF8String);
        if (![self save:text])
            return;
        self.finished = YES;
        self.result = 0;
        [self.window orderOut:nil];
        [self stop];
    }];
}

- (void)copyGoogleSession
{
    if (self.copied)
        return;
    WKHTTPCookieStore *store = self.web.configuration.websiteDataStore.httpCookieStore;
    [store getAllCookies:^(NSArray<NSHTTPCookie *> *cookies) {
        if (self.finished || self.copied)
            return;
        NSMutableArray<NSHTTPCookie *> *google = [NSMutableArray array];
        BOOL session = NO;
        for (NSHTTPCookie *cookie in cookies) {
            if ([cookie.domain isEqualToString:@".google.com"] && [accountCookies() containsObject:cookie.name]) {
                session = session || [cookie.name isEqualToString:@"SAPISID"];
                [google addObject:cookie];
            }
        }
        if (!session)
            return;
        self.copied = YES;
        self.copying = YES;
        fprintf(stderr, "inicio de sesión: copiando %lu cookies de la cuenta de Google a youtube.com\n",
                (unsigned long)google.count);
        dispatch_group_t group = dispatch_group_create();
        for (NSHTTPCookie *cookie in google) {
            NSMutableDictionary *properties = [cookie.properties mutableCopy];
            properties[NSHTTPCookieDomain] = @".youtube.com";
            NSHTTPCookie *copy = [NSHTTPCookie cookieWithProperties:properties];
            if (!copy)
                continue;
            dispatch_group_enter(group);
            [store setCookie:copy completionHandler:^{ dispatch_group_leave(group); }];
        }
        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            self.copying = NO;
            [self.web loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://music.youtube.com/"]]];
        });
    }];
}

- (BOOL)save:(NSString *)text
{
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    int fd = open(self.outPath.fileSystemRepresentation, O_WRONLY | O_CREAT | O_TRUNC, 0600);
    if (fd < 0)
        return NO;
    fchmod(fd, 0600);
    BOOL ok = write(fd, data.bytes, data.length) == (ssize_t)data.length;
    close(fd);
    return ok;
}

- (void)stop
{
    [NSApp stop:nil];
    // `stop:` solo surte efecto al procesar el siguiente evento.
    NSEvent *wake = [NSEvent otherEventWithType:NSEventTypeApplicationDefined
                                       location:NSZeroPoint
                                  modifierFlags:0
                                      timestamp:0
                                   windowNumber:0
                                        context:nil
                                        subtype:0
                                          data1:0
                                          data2:0];
    [NSApp postEvent:wake atStart:YES];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    // Depuración: MUSICPLAYER_LOGIN_SHOT=ruta.png guarda la primera página cargada y sale (3).
    const char *shot = getenv("MUSICPLAYER_LOGIN_SHOT");
    if (shot && !self.finished) {
        self.finished = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [webView takeSnapshotWithConfiguration:nil completionHandler:^(NSImage *image, NSError *) {
                NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:image.TIFFRepresentation];
                [[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}]
                    writeToFile:[NSString stringWithUTF8String:shot] atomically:YES];
                fprintf(stderr, "página: %s\n", webView.URL.absoluteString.UTF8String);
                self.result = 3;
                [self stop];
            }];
        });
        return;
    }
    [self check];
}

// Enlaces que abren ventana nueva («Más información», ayuda…): en la misma vista.
- (WKWebView *)webView:(WKWebView *)webView
    createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration
               forNavigationAction:(WKNavigationAction *)navigationAction
                    windowFeatures:(WKWindowFeatures *)windowFeatures
{
    if (navigationAction.request.URL)
        [webView loadRequest:navigationAction.request];
    return nil;
}

- (void)windowWillClose:(NSNotification *)notification
{
    if (self.finished)
        return;
    self.finished = YES;
    self.result = 1;
    [self stop];
}

@end

// Menú mínimo: sin menú «Edición» no funcionan ⌘V, ⌘C ni ⌘A en los campos de la web
// (pegar la contraseña desde un gestor, por ejemplo).
static void installMenu()
{
    NSMenu *bar = [[NSMenu alloc] init];

    NSMenuItem *appItem = [[NSMenuItem alloc] init];
    NSMenu *appMenu = [[NSMenu alloc] init];
    [appMenu addItemWithTitle:@"Cancelar inicio de sesión" action:@selector(performClose:) keyEquivalent:@"q"];
    appItem.submenu = appMenu;
    [bar addItem:appItem];

    NSMenuItem *editItem = [[NSMenuItem alloc] init];
    NSMenu *edit = [[NSMenu alloc] initWithTitle:@"Edición"];
    [edit addItemWithTitle:@"Deshacer" action:@selector(undo:) keyEquivalent:@"z"];
    NSMenuItem *redo = [edit addItemWithTitle:@"Rehacer" action:@selector(redo:) keyEquivalent:@"z"];
    redo.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    [edit addItem:[NSMenuItem separatorItem]];
    [edit addItemWithTitle:@"Cortar" action:@selector(cut:) keyEquivalent:@"x"];
    [edit addItemWithTitle:@"Copiar" action:@selector(copy:) keyEquivalent:@"c"];
    [edit addItemWithTitle:@"Pegar" action:@selector(paste:) keyEquivalent:@"v"];
    [edit addItemWithTitle:@"Seleccionar todo" action:@selector(selectAll:) keyEquivalent:@"a"];
    editItem.submenu = edit;
    [bar addItem:editItem];

    NSMenuItem *windowItem = [[NSMenuItem alloc] init];
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"Ventana"];
    [windowMenu addItemWithTitle:@"Cerrar" action:@selector(performClose:) keyEquivalent:@"w"];
    [windowMenu addItemWithTitle:@"Minimizar" action:@selector(performMiniaturize:) keyEquivalent:@"m"];
    windowItem.submenu = windowMenu;
    [bar addItem:windowItem];

    NSApp.mainMenu = bar;
}

extern "C" int musicplayer_login(const char *out_path)
{
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        installMenu();

        MPLogin *login = [[MPLogin alloc] init];
        login.outPath = [NSString stringWithUTF8String:out_path];
        login.result = 1;
        [login open];
        [NSApp run];
        return login.result;
    }
}
