// location.service.ts
import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { lastValueFrom } from 'rxjs';

export interface Region {
  code: string;
  name: string;
}

export interface LocationData {
  [regionCode: string]: {
    region_name: string;
    province_list: {
      [provinceName: string]: {
        municipality_list: {
          [municipalityName: string]: {
            barangay_list: string[];
          };
        };
      };
    };
  };
}

@Injectable({
  providedIn: 'root'
})
export class LocationService {
  private phLocations: LocationData | null = null;
  private isLoading = false;

  constructor(private http: HttpClient) {}

  async loadLocationData(): Promise<LocationData> {
    if (this.phLocations) {
      return this.phLocations;
    }

    if (this.isLoading) {
      // Wait for existing load to complete
      return new Promise((resolve) => {
        const checkInterval = setInterval(() => {
          if (this.phLocations) {
            clearInterval(checkInterval);
            resolve(this.phLocations);
          }
        }, 100);
      });
    }

    this.isLoading = true;
    try {
      this.phLocations = await lastValueFrom(
        this.http.get<LocationData>('assets/data/phil.json')
      );
      this.isLoading = false;
      return this.phLocations!;
    } catch (error) {
      this.isLoading = false;
      throw error;
    }
  }

  getRegions(): Region[] {
    if (!this.phLocations) return [];
    return Object.keys(this.phLocations).map(key => ({
      code: key,
      name: this.phLocations![key].region_name
    }));
  }

  getProvincesByRegion(regionCode: string): string[] {
    if (!this.phLocations || !this.phLocations[regionCode]) return [];
    return Object.keys(this.phLocations[regionCode].province_list);
  }

  getMunicipalitiesByProvince(regionCode: string, provinceName: string): string[] {
    if (!this.phLocations || 
        !this.phLocations[regionCode] || 
        !this.phLocations[regionCode].province_list[provinceName]) {
      return [];
    }
    return Object.keys(this.phLocations[regionCode].province_list[provinceName].municipality_list);
  }

  getBarangaysByMunicipality(regionCode: string, provinceName: string, municipalityName: string): string[] {
    if (!this.phLocations || 
        !this.phLocations[regionCode] || 
        !this.phLocations[regionCode].province_list[provinceName] ||
        !this.phLocations[regionCode].province_list[provinceName].municipality_list[municipalityName]) {
      return [];
    }
    return this.phLocations[regionCode].province_list[provinceName].municipality_list[municipalityName].barangay_list;
  }

  getRegionByProvince(provinceName: string): { regionCode: string, regionName: string } | null {
    if (!this.phLocations) return null;

    for (const regionCode in this.phLocations) {
      const region = this.phLocations[regionCode];
      if (region.province_list[provinceName]) {
        return {
          regionCode: regionCode,
          regionName: region.region_name
        };
      }
    }
    return null;
  }
  // Add this method to your LocationService in location.service.ts

    // ✅ NEW: Get region by name (needed for debt customer registration)
    getRegionByName(regionName: string): { regionCode: string; regionName: string } | null {
    if (!this.phLocations) return null;

    for (const regionCode in this.phLocations) {
        const region = this.phLocations[regionCode];
        if (region.region_name === regionName) {
        return {
            regionCode: regionCode,
            regionName: region.region_name
        };
        }
    }
    return null;
    }

    // ✅ NEW: Get all regions for reference
    getAllRegions(): { regionCode: string; regionName: string }[] {
    if (!this.phLocations) return [];
    
    return Object.keys(this.phLocations).map(regionCode => ({
        regionCode: regionCode,
        regionName: this.phLocations![regionCode].region_name
    }));
    }

  getStoreOwnerLocationData(storeOwnerProvince: string) {
    const regionInfo = this.getRegionByProvince(storeOwnerProvince);
    if (!regionInfo) return null;

    const municipalities = this.getMunicipalitiesByProvince(regionInfo.regionCode, storeOwnerProvince);
    
    return {
      regionCode: regionInfo.regionCode,
      regionName: regionInfo.regionName,
      province: storeOwnerProvince,
      municipalities: municipalities
    };
  }
}