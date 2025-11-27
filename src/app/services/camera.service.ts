import { Injectable } from '@angular/core';
import { Camera, CameraResultType, CameraSource, Photo } from '@capacitor/camera';
import { Capacitor } from '@capacitor/core';

@Injectable({
  providedIn: 'root'
})
export class CameraService {
  
  constructor() {
    // Initialize PWA Elements for web platform
    this.initializePwaElements();
  }

  private async initializePwaElements() {
    if (Capacitor.getPlatform() === 'web') {
      try {
        // Dynamically import and initialize PWA Elements
        const { defineCustomElements } = await import('@ionic/pwa-elements/loader');
        defineCustomElements(window);
        console.log('PWA Elements initialized');
      } catch (error) {
        console.warn('PWA Elements not available:', error);
      }
    }
  }

  async takePicture(): Promise<string> {
    try {
      console.log('Opening camera...');
      
      // Check camera permissions first
      const permissions = await Camera.checkPermissions();
      console.log('Camera permissions:', permissions);
      
      if (permissions.camera !== 'granted' || permissions.photos !== 'granted') {
        // Request permissions
        const requested = await Camera.requestPermissions();
        console.log('Requested permissions:', requested);
        
        if (requested.camera !== 'granted' || requested.photos !== 'granted') {
          throw new Error('Camera permission denied');
        }
      }

      const image = await Camera.getPhoto({
        quality: 90,
        allowEditing: false,
        resultType: CameraResultType.DataUrl,
        source: CameraSource.Camera,
        correctOrientation: true,
        promptLabelHeader: 'Take Photo',
        promptLabelPhoto: 'From Gallery',
        promptLabelPicture: 'Take Picture'
      });

      if (image.dataUrl) {
        console.log('Image captured successfully');
        return image.dataUrl;
      }
      throw new Error('No image data received');
      
    } catch (error: any) {
      console.error('Camera error:', error);
      
      // Handle specific error cases
      if (error.message.includes('canceled') || error.message.includes('User cancelled')) {
        throw new Error('Camera canceled by user');
      }
      
      if (error.message.includes('permission')) {
        throw new Error('Camera permission denied. Please enable camera access in your browser settings.');
      }
      
      if (error.message.includes('not available')) {
        throw new Error('Camera not available on this device');
      }
      
      // Fallback to file input
      console.log('Trying fallback camera...');
      return this.takePictureFallback();
    }
  }

  private takePictureFallback(): Promise<string> {
    return new Promise((resolve, reject) => {
      console.log('Using fallback camera method');
      
      const input = document.createElement('input');
      input.type = 'file';
      input.accept = 'image/*';
      input.capture = 'environment'; // Prefer rear camera on mobile
      
      let resolved = false;
      
      const cleanup = () => {
        document.body.removeChild(input);
        resolved = true;
      };
      
      input.onchange = (event: any) => {
        const file = event.target.files[0];
        if (file) {
          const reader = new FileReader();
          reader.onload = (e: any) => {
            if (!resolved) {
              cleanup();
              resolve(e.target.result);
            }
          };
          reader.onerror = () => {
            if (!resolved) {
              cleanup();
              reject(new Error('Failed to read file'));
            }
          };
          reader.readAsDataURL(file);
        } else {
          if (!resolved) {
            cleanup();
            reject(new Error('No file selected'));
          }
        }
      };
      
      input.oncancel = () => {
        if (!resolved) {
          cleanup();
          reject(new Error('Camera canceled by user'));
        }
      };
      
      // Add to DOM and trigger click
      input.style.display = 'none';
      document.body.appendChild(input);
      
      // Use a small timeout to ensure the element is in DOM
      setTimeout(() => {
        if (!resolved) {
          input.click();
        }
      }, 100);
      
      // Timeout after 30 seconds
      setTimeout(() => {
        if (!resolved) {
          cleanup();
          reject(new Error('Camera timeout'));
        }
      }, 30000);
    });
  }

  async pickFromGallery(): Promise<string> {
    try {
      console.log('Opening gallery...');
      
      const image = await Camera.getPhoto({
        quality: 90,
        allowEditing: false,
        resultType: CameraResultType.DataUrl,
        source: CameraSource.Photos
      });

      if (image.dataUrl) {
        console.log('Image selected from gallery');
        return image.dataUrl;
      }
      throw new Error('No image data received');
      
    } catch (error: any) {
      console.error('Gallery error:', error);
      
      if (error.message.includes('canceled') || error.message.includes('User cancelled')) {
        throw new Error('Gallery canceled by user');
      }
      
      // Fallback to basic file input
      return this.pickFromGalleryFallback();
    }
  }

  private pickFromGalleryFallback(): Promise<string> {
    return new Promise((resolve, reject) => {
      console.log('Using fallback gallery method');
      
      const input = document.createElement('input');
      input.type = 'file';
      input.accept = 'image/*';
      
      let resolved = false;
      
      const cleanup = () => {
        document.body.removeChild(input);
        resolved = true;
      };
      
      input.onchange = (event: any) => {
        const file = event.target.files[0];
        if (file) {
          const reader = new FileReader();
          reader.onload = (e: any) => {
            if (!resolved) {
              cleanup();
              resolve(e.target.result);
            }
          };
          reader.onerror = () => {
            if (!resolved) {
              cleanup();
              reject(new Error('Failed to read file'));
            }
          };
          reader.readAsDataURL(file);
        } else {
          if (!resolved) {
            cleanup();
            reject(new Error('No file selected'));
          }
        }
      };
      
      input.oncancel = () => {
        if (!resolved) {
          cleanup();
          reject(new Error('Gallery canceled by user'));
        }
      };
      
      input.style.display = 'none';
      document.body.appendChild(input);
      
      setTimeout(() => {
        if (!resolved) {
          input.click();
        }
      }, 100);
    });
  }

  // Utility method to check camera availability
  async checkCameraAvailability(): Promise<boolean> {
    try {
      if (Capacitor.isNativePlatform()) {
        return true; // Assume camera is available on native platforms
      }
      
      // For web platform
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        console.warn('Camera API not available in this browser');
        return false;
      }
      
      const stream = await navigator.mediaDevices.getUserMedia({ video: true });
      if (stream) {
        stream.getTracks().forEach(track => track.stop());
        return true;
      }
      return false;
    } catch (error) {
      console.log('Camera not available:', error);
      return false;
    }
  }
}