import { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'your.app.id',
  appName: 'Credilink',
  webDir: 'www',
  server: {
    androidScheme: 'https'
  },
  plugins: {
    Camera: {
      enableStorage: true
    }
  }
};

export default config;