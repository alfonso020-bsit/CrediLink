// src/app/services/quagga-barcode-scanner.service.ts
import { Injectable } from '@angular/core';
import Quagga from 'quagga'; // Proper import

@Injectable({
  providedIn: 'root'
})
export class QuaggaBarcodeScannerService {
  private isScanning = false;

  constructor() {}

  async scanBarcode(): Promise<string | null> {
    return new Promise((resolve, reject) => {
      if (this.isScanning) {
        reject(new Error('Scanner is already active'));
        return;
      }

      this.isScanning = true;

      // Create scanner UI
      const container = this.createScannerUI();
      
      const scannerElement = container.querySelector('#quagga-scanner') as HTMLDivElement;

      // Initialize Quagga
      Quagga.init({
        inputStream: {
          name: "Live",
          type: "LiveStream",
          target: scannerElement,
          constraints: {
            width: 640,
            height: 480,
            facingMode: "environment"
          },
        },
        decoder: {
          readers: [
            "ean_reader",
            "ean_8_reader",
            "code_128_reader",
            "code_39_reader",
            "upc_reader",
            "upc_e_reader"
          ]
        },
        locator: {
          patchSize: "medium",
          halfSample: true
        },
        locate: true,
        numOfWorkers: 2
      }, (err: any) => {
        if (err) {
          console.error('Quagga initialization error:', err);
          this.cleanup();
          reject(new Error('Failed to initialize scanner: ' + err.message));
          return;
        }

        console.log('Quagga initialized successfully');
        Quagga.start();

        // Timeout after 25 seconds
        const timeout = setTimeout(() => {
          Quagga.stop();
          this.cleanup();
          reject(new Error('Scanning timeout. Please ensure good lighting and try again.'));
        }, 25000);

        // Handle detected barcodes
        Quagga.onDetected((result: any) => {
          console.log('Barcode detected:', result);
          if (result.codeResult && result.codeResult.code) {
            const code = result.codeResult.code;
            console.log('Barcode found:', code);
            Quagga.stop();
            clearTimeout(timeout);
            this.cleanup();
            resolve(code);
          }
        });

        // Close button handler
        const closeButton = container.querySelector('#close-quagga-scanner') as HTMLButtonElement;
        if (closeButton) {
          closeButton.onclick = () => {
            Quagga.stop();
            clearTimeout(timeout);
            this.cleanup();
            resolve(null);
          };
        }
      });
    });
  }

  async scanBarcodeFromFile(file: File): Promise<string | null> {
    return new Promise((resolve, reject) => {
      const url = URL.createObjectURL(file);
      
      Quagga.decodeSingle({
        decoder: {
          readers: [
            "ean_reader",
            "ean_8_reader", 
            "code_128_reader",
            "code_39_reader",
            "upc_reader",
            "upc_e_reader"
          ]
        },
        locate: true,
        src: url
      }, (result: any) => {
        URL.revokeObjectURL(url);
        
        if (result && result.codeResult && result.codeResult.code) {
          resolve(result.codeResult.code);
        } else {
          reject(new Error('No barcode found in image'));
        }
      });
    });
  }

  private createScannerUI(): HTMLDivElement {
    this.cleanup();

    const container = document.createElement('div');
    container.id = 'quagga-scanner-container';
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
      max-width: 500px;
      border: 3px solid #3880ff;
      border-radius: 12px;
      overflow: hidden;
      box-shadow: 0 4px 25px rgba(56, 128, 255, 0.3);
    `;

    const scannerElement = document.createElement('div');
    scannerElement.id = 'quagga-scanner';
    scannerElement.style.cssText = `
      width: 100%;
      height: 300px;
      background: #000;
    `;

    // Instructions
    const instructions = document.createElement('div');
    instructions.style.cssText = `
      color: white;
      text-align: center;
      margin-top: 20px;
      font-size: 14px;
      max-width: 500px;
      line-height: 1.5;
    `;
    instructions.innerHTML = `
      <div style="background: rgba(255,255,255,0.1); padding: 15px; border-radius: 8px;">
        <p style="margin: 0 0 10px 0; font-weight: bold; color: #3880ff;">📊 1D BARCODE SCANNER</p>
        <p style="margin: 5px 0;">• Works with UPC, EAN, Code 128, Code 39</p>
        <p style="margin: 5px 0;">• Hold steady 6-12 inches from barcode</p>
        <p style="margin: 5px 0;">• Ensure bright, even lighting</p>
        <p style="margin: 5px 0;">• Center barcode in the viewfinder</p>
        <p style="margin: 5px 0; color: #4caf50;">• Perfect for product barcodes!</p>
      </div>
    `;

    // Close button
    const closeButton = document.createElement('button');
    closeButton.id = 'close-quagga-scanner';
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

    scannerBox.appendChild(scannerElement);
    container.appendChild(scannerBox);
    container.appendChild(instructions);
    container.appendChild(closeButton);
    document.body.appendChild(container);

    return container;
  }

  private cleanup(): void {
    // Stop Quagga if running
    try {
      Quagga.stop();
    } catch (e) {
      console.log('Quagga already stopped');
    }

    // Remove scanner container
    const container = document.getElementById('quagga-scanner-container');
    if (container && container.parentNode) {
      container.parentNode.removeChild(container);
    }

    this.isScanning = false;
  }
}