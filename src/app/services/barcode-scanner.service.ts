import { Injectable } from '@angular/core';
import { BrowserMultiFormatReader } from '@zxing/browser';
import { Result } from '@zxing/library';
import { BehaviorSubject } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class BarcodeScannerService {
  private codeReader: BrowserMultiFormatReader;
  private isScanning = new BehaviorSubject<boolean>(false);

  constructor() {
    this.codeReader = new BrowserMultiFormatReader();
  }

  async scanBarcode(): Promise<string | null> {
    try {
      // Check if browser supports camera access
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        throw new Error('Camera access not supported in this browser');
      }

      // Create video element for scanning
      const videoElement = this.createVideoElement();
      document.body.appendChild(videoElement);

      const result = await new Promise<Result>((resolve, reject) => {
        this.codeReader.decodeFromVideoDevice(
          undefined, // Use undefined instead of null
          videoElement, 
          (result, error) => {
            if (result) {
              resolve(result);
            }
            if (error && !(error instanceof Error)) {
              reject(new Error('Scanning failed'));
            }
          }
        );

        // Timeout after 30 seconds
        setTimeout(() => {
          this.stopScan();
          reject(new Error('Scanning timeout'));
        }, 30000);
      });

      // Stop scanning and clean up
      this.stopScan();

      return result.getText();

    } catch (error: any) {
      this.stopScan();
      
      if (error.message.includes('permission') || error.name === 'NotAllowedError') {
        throw new Error('Camera permission denied. Please allow camera access.');
      } else if (error.message.includes('timeout')) {
        throw new Error('Scanning timeout. Please try again.');
      } else {
        throw new Error('Barcode scanning failed: ' + error.message);
      }
    }
  }

  private createVideoElement(): HTMLVideoElement {
    const videoElement = document.createElement('video');
    videoElement.style.position = 'fixed';
    videoElement.style.top = '50%';
    videoElement.style.left = '50%';
    videoElement.style.transform = 'translate(-50%, -50%)';
    videoElement.style.width = '300px';
    videoElement.style.height = '300px';
    videoElement.style.zIndex = '1000';
    videoElement.style.border = '2px solid #3880ff';
    videoElement.style.borderRadius = '8px';
    videoElement.setAttribute('id', 'barcode-scanner-video');
    return videoElement;
  }

  private cleanupVideoElements() {
    const videoElement = document.getElementById('barcode-scanner-video');
    if (videoElement) {
      document.body.removeChild(videoElement);
    }
  }

  stopScan(): void {
    // ZXing browser doesn't have reset(), so we need to stop the video tracks
    const videoElement = document.getElementById('barcode-scanner-video') as HTMLVideoElement;
    if (videoElement && videoElement.srcObject) {
      const stream = videoElement.srcObject as MediaStream;
      stream.getTracks().forEach(track => track.stop());
      videoElement.srcObject = null;
    }
    this.cleanupVideoElements();
  }

  // For file-based scanning (alternative method)
  async scanBarcodeFromFile(file: File): Promise<string | null> {
    try {
      // Create a temporary image element to read the file
      return new Promise((resolve, reject) => {
        const img = new Image();
        const url = URL.createObjectURL(file);
        
        img.onload = async () => {
          try {
            const result = await this.codeReader.decodeFromImageElement(img);
            URL.revokeObjectURL(url);
            resolve(result.getText());
          } catch (error) {
            URL.revokeObjectURL(url);
            reject(new Error('Could not read barcode from image'));
          }
        };
        
        img.onerror = () => {
          URL.revokeObjectURL(url);
          reject(new Error('Could not load image'));
        };
        
        img.src = url;
      });
    } catch (error) {
      throw new Error('Could not read barcode from image');
    }
  }

  // For URL-based scanning (alternative method)
  async scanBarcodeFromUrl(imageUrl: string): Promise<string | null> {
    try {
      const result = await this.codeReader.decodeFromImageUrl(imageUrl);
      return result.getText();
    } catch (error) {
      throw new Error('Could not read barcode from image URL');
    }
  }

  // Get available video devices (cameras)
  async getVideoDevices(): Promise<MediaDeviceInfo[]> {
    try {
      const devices = await navigator.mediaDevices.enumerateDevices();
      return devices.filter(device => device.kind === 'videoinput');
    } catch (error) {
      console.error('Error getting video devices:', error);
      return [];
    }
  }

  // Scan with specific device
  async scanBarcodeWithDevice(deviceId: string): Promise<string | null> {
    try {
      const videoElement = this.createVideoElement();
      document.body.appendChild(videoElement);

      const result = await new Promise<Result>((resolve, reject) => {
        this.codeReader.decodeFromVideoDevice(
          deviceId,
          videoElement, 
          (result, error) => {
            if (result) {
              resolve(result);
            }
            if (error && !(error instanceof Error)) {
              reject(new Error('Scanning failed'));
            }
          }
        );

        setTimeout(() => {
          this.stopScan();
          reject(new Error('Scanning timeout'));
        }, 30000);
      });

      this.stopScan();
      return result.getText();

    } catch (error: any) {
      this.stopScan();
      throw new Error('Barcode scanning failed: ' + error.message);
    }
  }
}