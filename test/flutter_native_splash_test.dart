import 'dart:io';

import 'package:flutter_native_splash/cli_commands.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as p;

void main() {
  test('parseColor parses values correctly', () {
    expect(parseColor('#ffffff'), 'ffffff');
    expect(parseColor(' FAFAFA '), 'FAFAFA');
    expect(parseColor('121212'), '121212');
    expect(parseColor(null), null);
    expect(() => parseColor('badcolor'), throwsException);
  });

  group('config file from args', () {
    final testDir = p.join(
      '.dart_tool',
      'flutter_native_splash',
      'test',
      'config_file',
    );

    void setCurrentDirectory(String path) {
      final pathValue = p.join(testDir, path);
      Directory(pathValue).createSync(recursive: true);
      Directory.current = pathValue;
    }

    test('default', () {
      setCurrentDirectory('default');
      File('flutter_native_splash.yaml').writeAsStringSync('''
flutter_native_splash:
  color: "#00ff00"
''');
      final Map<String, dynamic> config = getConfig(
        configFile: 'flutter_native_splash.yaml',
        flavor: null,
      );
      File('flutter_native_splash.yaml').deleteSync();
      expect(config, isNotNull);
      expect(config['color'], '#00ff00');
    });
    test('default_use_pubspec', () {
      setCurrentDirectory('pubspec_only');
      File('pubspec.yaml').writeAsStringSync('''
flutter_native_splash:
  color: "#00ff00"
''');
      final Map<String, dynamic> config = getConfig(
        configFile: null,
        flavor: null,
      );
      File('pubspec.yaml').deleteSync();
      expect(config, isNotNull);
      expect(config['color'], '#00ff00');

      // fails if config file is missing
      expect(() => getConfig(configFile: null, flavor: null), throwsException);
    });
  });

  group('Android 12 image generation', () {
    late String originalDirectory;
    final testDir = p.join(
      '.dart_tool',
      'flutter_native_splash',
      'test',
      'android_12',
    );

    setUp(() {
      originalDirectory = Directory.current.path;
    });

    tearDown(() {
      Directory.current = originalDirectory;
    });

    void setCurrentDirectory(String path) {
      final pathValue = p.join(originalDirectory, testDir, path);
      if (Directory(pathValue).existsSync()) {
        Directory(pathValue).deleteSync(recursive: true);
      }
      Directory(pathValue).createSync(recursive: true);
      Directory.current = pathValue;
      Directory('android').createSync();
      File('android/app/src/main/AndroidManifest.xml')
        ..createSync(recursive: true)
        ..writeAsStringSync('''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application>
        <activity android:name=".MainActivity" />
    </application>
</manifest>
''');
      Directory('assets').createSync();
    }

    void writePng(String path, {int width = 512, int height = 512}) {
      final png = image.Image(width: width, height: height, numChannels: 4);
      image.fill(png, color: image.ColorRgba8(255, 0, 0, 255));
      File(path).writeAsBytesSync(image.encodePng(png));
    }

    image.Image readGeneratedImage(String path) {
      final generated = image.decodeImage(File(path).readAsBytesSync());
      expect(generated, isNotNull);
      return generated!;
    }

    test('uses 288dp icon when icon background color is omitted', () {
      setCurrentDirectory('without_icon_background');
      writePng('assets/splash.png');
      File('flutter_native_splash.yaml').writeAsStringSync('''
flutter_native_splash:
  android: true
  ios: false
  web: false
  color: "#ffffff"
  android_12:
    image: assets/splash.png
    color: "#ffffff"
''');

      createSplash(path: 'flutter_native_splash.yaml', flavor: null);

      final splash = readGeneratedImage(
        'android/app/src/main/res/drawable-mdpi-v31/android12splash.png',
      );
      expect(splash.width, 288);
      expect(splash.height, 288);
    });

    test('uses 240dp icon when icon background color is provided', () {
      setCurrentDirectory('with_icon_background');
      writePng('assets/splash.png');
      File('flutter_native_splash.yaml').writeAsStringSync('''
flutter_native_splash:
  android: true
  ios: false
  web: false
  color: "#ffffff"
  android_12:
    image: assets/splash.png
    color: "#ffffff"
    icon_background_color: "#111111"
''');

      createSplash(path: 'flutter_native_splash.yaml', flavor: null);

      final splash = readGeneratedImage(
        'android/app/src/main/res/drawable-mdpi-v31/android12splash.png',
      );
      expect(splash.width, 240);
      expect(splash.height, 240);
      expect(
        File(
          'android/app/src/main/res/values-v31/styles.xml',
        ).readAsStringSync(),
        contains('android:windowSplashScreenIconBackgroundColor'),
      );
    });

    test('uses 200x80dp branding image', () {
      setCurrentDirectory('branding');
      writePng('assets/splash.png');
      writePng('assets/branding.png', width: 1000, height: 300);
      File('flutter_native_splash.yaml').writeAsStringSync('''
flutter_native_splash:
  android: true
  ios: false
  web: false
  color: "#ffffff"
  android_12:
    image: assets/splash.png
    branding: assets/branding.png
    color: "#ffffff"
''');

      createSplash(path: 'flutter_native_splash.yaml', flavor: null);

      final branding = readGeneratedImage(
        'android/app/src/main/res/drawable-mdpi-v31/android12branding.png',
      );
      expect(branding.width, 200);
      expect(branding.height, 80);
    });

    test('creates API 23 launch theme with matching status bar', () {
      setCurrentDirectory('api_23_status_bar');
      writePng('assets/splash.png');
      File('flutter_native_splash.yaml').writeAsStringSync('''
flutter_native_splash:
  android: true
  ios: false
  web: false
  color: "#ffffff"
  color_dark: "#000000"
  image: assets/splash.png
  android_12:
    image: assets/splash.png
    color: "#ffffff"
    color_dark: "#000000"
''');

      createSplash(path: 'flutter_native_splash.yaml', flavor: null);

      final lightStyles = File(
        'android/app/src/main/res/values-v23/styles.xml',
      ).readAsStringSync();
      final darkStyles = File(
        'android/app/src/main/res/values-night-v23/styles.xml',
      ).readAsStringSync();
      expect(lightStyles, contains('android:statusBarColor'));
      expect(lightStyles, contains('#ffffff'));
      expect(lightStyles, contains('android:windowLightStatusBar'));
      expect(lightStyles, contains('true'));
      expect(darkStyles, contains('#000000'));
      expect(darkStyles, contains('false'));
    });

    test('uses animated vector drawable and animation duration', () {
      setCurrentDirectory('animated_vector');
      File('assets/animated_splash.xml').writeAsStringSync('''
<animated-vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:drawable="@drawable/animated_splash_vector">
</animated-vector>
''');
      File('flutter_native_splash.yaml').writeAsStringSync('''
flutter_native_splash:
  android: true
  ios: false
  web: false
  color: "#ffffff"
  android_12:
    image: assets/animated_splash.xml
    color: "#ffffff"
    animation_duration: 750
''');

      createSplash(path: 'flutter_native_splash.yaml', flavor: null);

      expect(
        File(
          'android/app/src/main/res/drawable-mdpi-v31/android12splash.xml',
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          'android/app/src/main/res/drawable-mdpi-v31/android12splash.png',
        ).existsSync(),
        isFalse,
      );
      expect(
        File(
          'android/app/src/main/res/values-v31/styles.xml',
        ).readAsStringSync(),
        allOf(
          contains('android:windowSplashScreenAnimationDuration'),
          contains('750'),
          contains('@drawable/android12splash'),
        ),
      );
    });
  });
}
