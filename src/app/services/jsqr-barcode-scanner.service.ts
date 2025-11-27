import { Injectable } from '@angular/core';
import jsQR from 'jsqr';

@Injectable({
  providedIn: 'root'
})
export class JsqrBarcodeScannerService {
  private videoElement: HTMLVideoElement | null = null;
  private canvasElement: HTMLCanvasElement | null = null;
  private canvasContext: CanvasRenderingContext2D | null = null;
  private isScanning = false;
  private scanInterval: any = null;

  constructor() {}

  async scanBarcode(): Promise<string | null> {
    if (this.isScanning) {
      throw new Error('Scanner is already active');
    }

    this.isScanning = true;

    try {
      // Check browser support
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        throw new Error('Camera access not supported in this browser');
      }

      // Create scanner UI
      const { videoElement, canvasElement, container } = this.createScannerUI();
      this.videoElement = videoElement;
      this.canvasElement = canvasElement;
      this.canvasContext = canvasElement.getContext('2d');

      // Start camera
      await this.startCamera(videoElement);

      return new Promise<string | null>((resolve, reject) => {
        let scanTimeout: any;
        let consecutiveMatches = 0;
        let lastResult: string | null = null;

        // Start scanning loop
        this.scanInterval = setInterval(() => {
          if (videoElement.readyState === videoElement.HAVE_ENOUGH_DATA) {
            this.scanFrame(videoElement, (result) => {
              if (result) {
                if (result === lastResult) {
                  consecutiveMatches++;
                  if (consecutiveMatches >= 2) { // Require 2 consecutive matches
                    this.stopScan();
                    clearTimeout(scanTimeout);
                    resolve(result);
                  }
                } else {
                  lastResult = result;
                  consecutiveMatches = 1;
                }
              }
            });
          }
        }, 100); // Scan every 100ms for faster response

        // Timeout after 20 seconds
        scanTimeout = setTimeout(() => {
          this.stopScan();
          reject(new Error('Scanning took too long. Please ensure good lighting and try again.'));
        }, 20000);

        // Close button handler
        const closeButton = container.querySelector('#close-scanner') as HTMLButtonElement;
        if (closeButton) {
          closeButton.onclick = () => {
            this.stopScan();
            clearTimeout(scanTimeout);
            resolve(null);
          };
        }
      });

    } catch (error: any) {
      this.isScanning = false;
      throw new Error('Barcode scanning failed: ' + error.message);
    }
  }

  private createScannerUI(): { 
    videoElement: HTMLVideoElement; 
    canvasElement: HTMLCanvasElement;
    container: HTMLDivElement;
  } {
    const container = document.createElement('div');
    container.style.cssText = `
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      background: rgba(0, 0, 0, 0.95);
      z-index: 10000;
      display: flex;
      flex-direction: column;
      justify-content: center;
      align-items: center;
      padding: 20px;
      font-family: Arial, sans-serif;
    `;

    const scannerBox = document.createElement('div');
    scannerBox.style.cssText = `
      position: relative;
      width: 100%;
      max-width: 400px;
      border: 3px solid #3880ff;
      border-radius: 12px;
      overflow: hidden;
      box-shadow: 0 4px 25px rgba(56, 128, 255, 0.3);
    `;

    const videoElement = document.createElement('video');
    videoElement.style.cssText = `
      width: 100%;
      height: auto;
      display: block;
      background: #000;
    `;
    videoElement.setAttribute('autoplay', 'true');
    videoElement.setAttribute('playsinline', 'true');
    videoElement.setAttribute('muted', 'true');

    const canvasElement = document.createElement('canvas');
    canvasElement.style.cssText = `
      display: none;
    `;

    // Scanner overlay with guide
    const overlay = document.createElement('div');
    overlay.style.cssText = `
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      pointer-events: none;
      background: transparent;
    `;

    // Scanning area indicator
    const scanArea = document.createElement('div');
    scanArea.style.cssText = `
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      width: 70%;
      height: 30%;
      border: 2px solid #00ff00;
      border-radius: 8px;
      box-shadow: 0 0 0 5000px rgba(0, 0, 0, 0.7);
    `;

    // Scanning animation
    const scanLine = document.createElement('div');
    scanLine.style.cssText = `
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 3px;
      background: #00ff00;
      animation: scan 2s linear infinite;
      box-shadow: 0 0 10px #00ff00;
    `;

    const scanLineStyle = document.createElement('style');
    scanLineStyle.textContent = `
      @keyframes scan {
        0% { top: 0; }
        100% { top: 100%; }
      }
    `;
    document.head.appendChild(scanLineStyle);

    overlay.appendChild(scanArea);
    scanArea.appendChild(scanLine);

    // Instructions
    const instructions = document.createElement('div');
    instructions.style.cssText = `
      color: white;
      text-align: center;
      margin-top: 25px;
      font-size: 14px;
      max-width: 400px;
      line-height: 1.5;
    `;
    instructions.innerHTML = `
      <div style="background: rgba(255,255,255,0.1); padding: 15px; border-radius: 8px;">
        <p style="margin: 0 0 10px 0; font-weight: bold; color: #3880ff;">📷 SCANNING TIPS:</p>
        <p style="margin: 5px 0;">• Hold steady 4-8 inches from barcode</p>
        <p style="margin: 5px 0;">• Ensure bright, even lighting</p>
        <p style="margin: 5px 0;">• Center barcode in the green box</p>
        <p style="margin: 5px 0;">• Avoid shadows and glare</p>
      </div>
    `;

    // Close button
    const closeButton = document.createElement('button');
    closeButton.id = 'close-scanner';
    closeButton.style.cssText = `
      margin-top: 20px;
      padding: 12px 30px;
      background: #ff3b30;
      color: white;
      border: none;
      border-radius: 8px;
      font-size: 16px;
      cursor: pointer;
      font-weight: bold;
      transition: background 0.3s;
    `;
    closeButton.textContent = '✕ Close Scanner';
    closeButton.onmouseover = () => closeButton.style.background = '#ff1a1a';
    closeButton.onmouseout = () => closeButton.style.background = '#ff3b30';

    scannerBox.appendChild(videoElement);
    scannerBox.appendChild(canvasElement);
    scannerBox.appendChild(overlay);
    container.appendChild(scannerBox);
    container.appendChild(instructions);
    container.appendChild(closeButton);
    document.body.appendChild(container);

    return { videoElement, canvasElement, container };
  }

  private async startCamera(videoElement: HTMLVideoElement): Promise<void> {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: 'environment', // Prefer rear camera
          width: { ideal: 1280 },
          height: { ideal: 720 },
          frameRate: { ideal: 30 }
        },
        audio: false
      });

      videoElement.srcObject = stream;
      await videoElement.play();

    } catch (error: any) {
      if (error.name === 'NotAllowedError') {
        throw new Error('Camera permission denied. Please allow camera access in your browser settings.');
      } else if (error.name === 'NotFoundError') {
        throw new Error('No camera found on this device.');
      } else {
        throw new Error('Failed to access camera: ' + error.message);
      }
    }
  }

  private scanFrame(
    video: HTMLVideoElement,
    callback: (result: string | null) => void
  ): void {
    if (!this.canvasElement || !this.canvasContext) return;

    // Set canvas dimensions to match video
    this.canvasElement.width = video.videoWidth;
    this.canvasElement.height = video.videoHeight;

    // Draw video frame to canvas
    this.canvasContext.drawImage(video, 0, 0, this.canvasElement.width, this.canvasElement.height);

    // Get image data from canvas
    const imageData = this.canvasContext.getImageData(0, 0, this.canvasElement.width, this.canvasElement.height);

    // Scan for barcodes
    const code = jsQR(imageData.data, imageData.width, imageData.height, {
      inversionAttempts: 'dontInvert',
    });

    if (code) {
      callback(code.data);
    } else {
      callback(null);
    }
  }

  stopScan(): void {
    this.isScanning = false;

    // Stop scan interval
    if (this.scanInterval) {
      clearInterval(this.scanInterval);
      this.scanInterval = null;
    }

    // Stop camera stream
    if (this.videoElement && this.videoElement.srcObject) {
      const stream = this.videoElement.srcObject as MediaStream;
      stream.getTracks().forEach(track => track.stop());
      this.videoElement.srcObject = null;
    }

    // Remove scanner UI
    const scannerContainers = document.querySelectorAll('[style*="position: fixed"][style*="z-index: 10000"]');
    scannerContainers.forEach(container => {
      if (container.parentNode) {
        container.parentNode.removeChild(container);
      }
    });

    // Remove scan animation style
    const scanStyle = document.querySelector('style');
    if (scanStyle && scanStyle.textContent?.includes('@keyframes scan')) {
      scanStyle.remove();
    }

    this.videoElement = null;
    this.canvasElement = null;
    this.canvasContext = null;
  }

  // Scan from image file
  async scanBarcodeFromFile(file: File): Promise<string | null> {
    return new Promise((resolve, reject) => {
      const img = new Image();
      const url = URL.createObjectURL(file);

      img.onload = () => {
        const canvas = document.createElement('canvas');
        const context = canvas.getContext('2d');
        
        if (!context) {
          URL.revokeObjectURL(url);
          reject(new Error('Could not create canvas context'));
          return;
        }

        canvas.width = img.width;
        canvas.height = img.height;
        context.drawImage(img, 0, 0);

        const imageData = context.getImageData(0, 0, canvas.width, canvas.height);
        const code = jsQR(imageData.data, imageData.width, imageData.height, {
          inversionAttempts: 'dontInvert',
        });

        URL.revokeObjectURL(url);

        if (code) {
          resolve(code.data);
        } else {
          reject(new Error('No barcode found in image'));
        }
      };

      img.onerror = () => {
        URL.revokeObjectURL(url);
        reject(new Error('Could not load image'));
      };

      img.src = url;
    });
  }

  // Scan from image URL
  async scanBarcodeFromUrl(imageUrl: string): Promise<string | null> {
    return new Promise((resolve, reject) => {
      const img = new Image();
      img.crossOrigin = 'Anonymous';

      img.onload = () => {
        const canvas = document.createElement('canvas');
        const context = canvas.getContext('2d');
        
        if (!context) {
          reject(new Error('Could not create canvas context'));
          return;
        }

        canvas.width = img.width;
        canvas.height = img.height;
        context.drawImage(img, 0, 0);

        const imageData = context.getImageData(0, 0, canvas.width, canvas.height);
        const code = jsQR(imageData.data, imageData.width, imageData.height, {
          inversionAttempts: 'dontInvert',
        });

        if (code) {
          resolve(code.data);
        } else {
          reject(new Error('No barcode found in image'));
        }
      };

      img.onerror = () => {
        reject(new Error('Could not load image from URL'));
      };

      img.src = imageUrl;
    });
  }
}