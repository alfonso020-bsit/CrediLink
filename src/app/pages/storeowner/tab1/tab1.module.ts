import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';

import { IonicModule } from '@ionic/angular';

import { Tab1PageRoutingModule } from './tab1-routing.module';

import { Tab1Page } from './tab1.page';
import { CalendarViewComponent } from './calendar-view.component';
import { DebtViewComponent } from './debt-view.component';
@NgModule({
  imports: [
    CommonModule,
    FormsModule,
    IonicModule,
    Tab1PageRoutingModule
  ],
     declarations: [
      Tab1Page,
      CalendarViewComponent,
      DebtViewComponent // Add the modal component here
    ],
})
export class Tab1PageModule {}
