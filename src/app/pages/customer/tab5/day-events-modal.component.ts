import { Component, Input } from '@angular/core';
import { ModalController } from '@ionic/angular';
import { CalendarDay, CalendarEvent, DebtProduct } from './tab5.page';

@Component({
  selector: 'app-day-events-modal',
  template: `
<ion-header>
  <ion-toolbar color="primary">
    <ion-buttons slot="start">
      <ion-button (click)="dismiss()">
        <ion-icon slot="icon-only" name="close"></ion-icon>
      </ion-button>
    </ion-buttons>
    <ion-title>Events on {{ getFormattedDate() }}</ion-title>
  </ion-toolbar>
</ion-header>

<ion-content>
  <div class="events-container">
    
    <!-- Debts Created Section -->
    <ion-card *ngIf="eventsByType.debt_created.length > 0" class="event-section-card">
      <ion-card-header>
        <ion-card-title class="section-title">
          <ion-icon name="document-text" color="primary"></ion-icon>
          Debts Created
        </ion-card-title>
      </ion-card-header>
      <ion-card-content>
        <ion-list lines="full">
          <ion-item *ngFor="let event of eventsByType.debt_created" 
                    button 
                    (click)="viewDebtDetails(event.debt!)"
                    detail>
            <ion-icon slot="start" name="document-text" color="primary"></ion-icon>
            <ion-label>
              <h3>{{ event.debt?.storeName }}</h3>
              <p>Amount: <strong>{{ formatCurrency(event.debt?.total || 0) }}</strong></p>
            </ion-label>
          </ion-item>
        </ion-list>
      </ion-card-content>
    </ion-card>

    <!-- Payments Made Section -->
    <ion-card *ngIf="eventsByType.payment_made.length > 0" class="event-section-card">
      <ion-card-header>
        <ion-card-title class="section-title">
          <ion-icon name="cash" color="success"></ion-icon>
          Payments Made
        </ion-card-title>
      </ion-card-header>
      <ion-card-content>
        <ion-list lines="full">
          <ion-item *ngFor="let event of eventsByType.payment_made" 
                    button 
                    (click)="viewDebtDetails(event.debt!)"
                    detail>
            <ion-icon slot="start" name="cash" color="success"></ion-icon>
            <ion-label>
              <h3>{{ event.debt?.storeName }}</h3>
              <p>Paid: <strong>{{ formatCurrency(event.payment?.amount || 0) }}</strong></p>
              <p *ngIf="event.payment?.paid_by" class="paid-by">
                <ion-icon name="person" size="small"></ion-icon>
                By: {{ event.payment?.paid_by }}
              </p>
            </ion-label>
          </ion-item>
        </ion-list>
      </ion-card-content>
    </ion-card>

    <!-- Due Dates Section -->
    <ion-card *ngIf="eventsByType.due_date.length > 0" class="event-section-card">
      <ion-card-header>
        <ion-card-title class="section-title">
          <ion-icon name="calendar" color="warning"></ion-icon>
          Payments Due
        </ion-card-title>
      </ion-card-header>
      <ion-card-content>
        <ion-list lines="full">
          <ion-item *ngFor="let event of eventsByType.due_date" 
                    button 
                    (click)="viewDebtDetails(event.debt!)"
                    detail
                    [class.overdue-item]="event.debt?.isOverdue">
            <ion-icon slot="start" 
                      name="calendar" 
                      [color]="event.debt?.isOverdue ? 'danger' : 'warning'"></ion-icon>
            <ion-label>
              <h3>{{ event.debt?.storeName }}</h3>
              <p>Amount Due: <strong>{{ formatCurrency(event.debt?.remainingBalance || 0) }}</strong></p>
              <ion-badge [color]="getStatusColor(event.debt?.isOverdue || false, event.debt?.days_remaining)" 
                         class="status-badge">
                {{ getStatusText(event.debt?.isOverdue || false, event.debt?.days_remaining) }}
              </ion-badge>
            </ion-label>
          </ion-item>
        </ion-list>
      </ion-card-content>
    </ion-card>

    <!-- New Stores Section -->
    <ion-card *ngIf="eventsByType.new_store.length > 0" class="event-section-card">
      <ion-card-header>
        <ion-card-title class="section-title">
          <ion-icon name="storefront" color="tertiary"></ion-icon>
          New Stores
        </ion-card-title>
      </ion-card-header>
      <ion-card-content>
        <ion-list lines="full">
          <ion-item *ngFor="let event of eventsByType.new_store">
            <ion-icon slot="start" name="storefront" color="tertiary"></ion-icon>
            <ion-label>
              <h3>{{ event.title }}</h3>
              <p>{{ event.description }}</p>
            </ion-label>
          </ion-item>
        </ion-list>
      </ion-card-content>
    </ion-card>

    <!-- No Events State -->
    <div *ngIf="day.events.length === 0" class="no-events">
      <ion-icon name="calendar-clear" size="large" color="medium"></ion-icon>
      <h2>No Events</h2>
      <p>There are no events scheduled for this day.</p>
    </div>

  </div>
</ion-content>

<ion-footer>
  <ion-toolbar>
    <ion-button expand="block" (click)="dismiss()" fill="clear">
      Close
    </ion-button>
  </ion-toolbar>
</ion-footer>
  `,
  styles: [`
ion-content {
  --background: #f8f9fa;
}

.events-container {
  padding: 16px;
  padding-bottom: 80px;
}

.event-section-card {
  margin-bottom: 16px;
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.event-section-card ion-card-header {
  padding: 12px 16px;
}

.section-title {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 16px;
  font-weight: 600;
  margin: 0;
}

.section-title ion-icon {
  font-size: 20px;
}

.event-section-card ion-card-content {
  padding: 0;
}

.event-section-card ion-list {
  background: transparent;
  padding: 0;
}

.event-section-card ion-item {
  --padding-start: 16px;
  --padding-end: 16px;
  --min-height: 70px;
  cursor: pointer;
  transition: background 0.2s ease;
}

.event-section-card ion-item:hover {
  --background: #f5f5f5;
}

.overdue-item {
  --background: #fff5f5;
  border-left: 4px solid var(--ion-color-danger);
}

ion-item ion-icon[slot="start"] {
  font-size: 24px;
  margin-right: 12px;
}

ion-label h3 {
  margin: 0 0 6px 0;
  font-size: 15px;
  font-weight: 600;
  color: var(--ion-color-dark);
}

ion-label p {
  margin: 0 0 4px 0;
  font-size: 13px;
  color: var(--ion-color-medium);
}

ion-label p strong {
  color: var(--ion-color-primary);
  font-weight: 600;
}

.paid-by {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 12px;
  color: var(--ion-color-medium);
}

.paid-by ion-icon {
  font-size: 12px;
}

.status-badge {
  margin-top: 4px;
  font-size: 10px;
  padding: 4px 8px;
}

.no-events {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 60px 20px;
  text-align: center;
}

.no-events ion-icon {
  margin-bottom: 16px;
  font-size: 64px;
  opacity: 0.5;
}

.no-events h2 {
  margin: 0 0 8px 0;
  font-size: 18px;
  font-weight: 600;
  color: var(--ion-color-dark);
}

.no-events p {
  margin: 0;
  font-size: 14px;
  color: var(--ion-color-medium);
}

ion-footer ion-toolbar {
  --background: white;
  --border-style: none;
  box-shadow: 0 -2px 8px rgba(0, 0, 0, 0.1);
}

ion-footer ion-button {
  margin: 8px;
  font-weight: 600;
}
  `],
  standalone: false,
})
export class DayEventsModalComponent {
  @Input() day!: CalendarDay;
  @Input() formatDate!: (date: any) => string;
  @Input() formatCurrency!: (amount: number) => string;

  eventsByType: {
    debt_created: CalendarEvent[];
    payment_made: CalendarEvent[];
    due_date: CalendarEvent[];
    new_store: CalendarEvent[];
  } = {
    debt_created: [],
    payment_made: [],
    due_date: [],
    new_store: []
  };

  constructor(private modalController: ModalController) {}

  ngOnInit() {
    this.day.events.forEach(event => {
      if (event.type in this.eventsByType) {
        this.eventsByType[event.type as keyof typeof this.eventsByType].push(event);
      }
    });
  }

  dismiss() {
    this.modalController.dismiss();
  }

  viewDebtDetails(debt: DebtProduct) {
    this.modalController.dismiss({
      action: 'viewDebt',
      debt: debt
    });
  }

  getStatusColor(isOverdue: boolean, dayRemaining?: number): string {
    if (isOverdue) return 'danger';
    if (dayRemaining !== undefined && dayRemaining <= 15 && dayRemaining >= 0) return 'warning';
    return 'primary';
  }

  getStatusText(isOverdue: boolean, dayRemaining?: number): string {
    if (isOverdue) return 'OVERDUE';
    if (dayRemaining !== undefined && dayRemaining <= 15 && dayRemaining >= 0) return 'DUE SOON';
    return 'ACTIVE';
  }

  getFormattedDate(): string {
    if (!this.day.date) return 'N/A';
    return this.formatDate(new Date(this.day.date));
  }
}