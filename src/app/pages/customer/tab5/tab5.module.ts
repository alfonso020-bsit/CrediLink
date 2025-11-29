import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';

import { IonicModule } from '@ionic/angular';

import { Tab5PageRoutingModule } from './tab5-routing.module';

import { Tab5Page } from './tab5.page';
import { DayEventsModalComponent } from './day-events-modal.component'; // ✅ Fixed import path

@NgModule({
  imports: [
    CommonModule,
    FormsModule,
    IonicModule,
    Tab5PageRoutingModule
    
  ],
  declarations: [
    Tab5Page,
    DayEventsModalComponent
]
})
export class Tab5PageModule {}
