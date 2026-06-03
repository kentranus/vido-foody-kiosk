import { CapacitorConfig } from '@capacitor/cli';

const appMode = process.env.VITE_APP_MODE || process.env.APP_MODE || 'pos';
const isKiosk = appMode === 'kiosk';

const config: CapacitorConfig = {
  appId: isKiosk ? 'com.vido.foody.kiosk' : 'com.vido.foody.pos',
  appName: isKiosk ? 'Vido Foody Kiosk' : 'Vido Foody POS',
  webDir: 'dist',
  bundledWebRuntime: false,
  android: {
    allowMixedContent: true,
    captureInput: true,
    webContentsDebuggingEnabled: true,
  },
  plugins: {
    SplashScreen: {
      launchShowDuration: 1200,
      backgroundColor: '#FFCC00',
      showSpinner: false,
    },
    StatusBar: {
      style: 'LIGHT',
      backgroundColor: '#FFCC00',
    },
  },
  server: {
    androidScheme: 'https',
    cleartext: true,
  },
};

export default config;
