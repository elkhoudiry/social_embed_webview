library social_embed_webview;

import 'package:flutter/material.dart';
import 'package:social_embed_webview/platforms/social-media-generic.dart';
import 'package:social_embed_webview/utils/common-utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SocialEmbed extends StatefulWidget {
  final SocialMediaGenericEmbedData socialMediaObj;
  final Color? backgroundColor;
  const SocialEmbed(
      {Key? key, required this.socialMediaObj, this.backgroundColor})
      : super(key: key);

  @override
  _SocialEmbedState createState() => _SocialEmbedState();
}

class _SocialEmbedState extends State<SocialEmbed> with WidgetsBindingObserver {
  double _height = 250;
  late WebViewController wbController;
  late SocialMediaGenericEmbedData smObj;
  late String htmlBody;

  @override
  void initState() {
    super.initState();
    smObj = widget.socialMediaObj;
    htmlBody = getHtmlBody();
    if (smObj.supportMediaControll) WidgetsBinding.instance!.addObserver(this);
  }

  @override
  void dispose() {
    if (smObj.supportMediaControll)
      WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        break;
      case AppLifecycleState.detached:
        wbController.evaluateJavascript(smObj.stopVideoScript);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        wbController.evaluateJavascript(smObj.pauseVideoScript);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final wv = WebView(
        initialUrl: htmlToURI(htmlBody),
        javascriptChannels:
            <JavascriptChannel>[_getHeightJavascriptChannel()].toSet(),
        javascriptMode: JavascriptMode.unrestricted,
        onWebViewCreated: (wbc) {
          wbController = wbc;
        },
        onPageFinished: (str) async {
          final color = colorToHtmlRGBA(getBackgroundColor(context));
          wbController.evaluateJavascript(
              'document.body.style= "background-color: $color"');
          if (smObj.aspectRatio == null)
            wbController
                .evaluateJavascript('setTimeout(() => sendHeight(), 0)');
          double finalHeight = _height;
          try {
            await Future.delayed(Duration(seconds: 3), () async {
              final log = "document.getElementById('widget').clientHeight;";
              finalHeight =
                  double.parse(await wbController.evaluateJavascript(log));
            });

            setState(() {
              _height = finalHeight < 250 ? 250 : finalHeight;
            });
          } catch (e) {}
        },
        navigationDelegate: (navigation) async {
          final url = navigation.url;
          if (navigation.isForMainFrame && await canLaunch(url)) {
            launch(url);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        });
    return SizedBox(
        height: _height,
        width: double.infinity,
        child: Center(
          child: wv,
        ));
  }

  JavascriptChannel _getHeightJavascriptChannel() {
    return JavascriptChannel(
        name: 'PageHeight', onMessageReceived: (JavascriptMessage message) {});
  }

  Color getBackgroundColor(BuildContext context) {
    final color = widget.backgroundColor;
    return (color == null) ? Theme.of(context).scaffoldBackgroundColor : color;
  }

  String getHtmlBody() => """
      <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            *{box-sizing: border-box;margin:0px; padding:0px;}
              #widget {
                        display: flex;
                        justify-content: center;
                        margin: 0 auto;
                        max-width:100%;
                    }      
          </style>
        </head>
        <body>
          <div id="widget" style="${smObj.htmlInlineStyling}">${smObj.htmlBody}</div>
          ${(smObj.aspectRatio == null) ? dynamicHeightScriptSetup : ''}
          ${(smObj.canChangeSize) ? dynamicHeightScriptCheck : ''}
        </body>
      </html>
    """;

  static const String dynamicHeightScriptSetup = """
    <script type="text/javascript">
      const widget = document.getElementById('widget');
      const sendHeight = () => PageHeight.postMessage(widget.clientHeight);
    </script>
  """;

  static const String dynamicHeightScriptCheck = """
    <script type="text/javascript">
      const onWidgetResize = (widgets) => sendHeight();
      const resize_ob = new ResizeObserver(onWidgetResize);
      resize_ob.observe(widget);
    </script>
  """;
}
