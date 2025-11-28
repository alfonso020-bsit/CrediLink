import { Component, Input, OnInit } from '@angular/core';
import { ModalController } from '@ionic/angular';

interface CalendarEvent {
  date: Date;
  type: 'transaction' | 'due_date';
  transactionId: string;
  customerName: string;
  amount: number;
  status: string;
  isOverdue?: boolean;
  debtData?: any;
}

type ViewMode = 'all' | 'upcoming' | 'overdue';

@Component({
  selector: 'app-calendar-view',
  templateUrl: './calendar-view.component.html',
  styleUrls: ['./calendar-view.component.scss'],
  standalone: false,
})
export class CalendarViewComponent implements OnInit {
  @Input() calendarEvents: CalendarEvent[] = [];
  @Input() storeName: string = '';
  @Input() selectedDate?: Date;
  @Input() employeeName?: string;

  filteredEvents: CalendarEvent[] = [];
  viewMode: ViewMode = 'all';
  
  // For calendar view
  currentMonth: Date = new Date();
  weeks: { date: Date; events: CalendarEvent[]; isCurrentMonth: boolean }[][] = [];

  constructor(private modalController: ModalController) {}

  ngOnInit() {
    if (this.selectedDate) {
      // Show events for specific date
      this.filteredEvents = this.calendarEvents.filter(event => 
        this.isSameDay(event.date, this.selectedDate!)
      );
    } else {
      // Show all events
      this.filteredEvents = [...this.calendarEvents];
      this.generateCalendar();
    }
  }

  // Close modal
  dismiss() {
    this.modalController.dismiss();
  }

  // Handle segment change
  onSegmentChange(event: any) {
    const mode = event.detail.value;
    if (mode === 'all' || mode === 'upcoming' || mode === 'overdue') {
      this.filterEvents(mode as ViewMode);
    }
  }

  // Filter events by view mode
  filterEvents(mode: ViewMode) {
    this.viewMode = mode;
    const today = new Date();
    
    switch (mode) {
      case 'upcoming':
        this.filteredEvents = this.calendarEvents.filter(event => 
          event.date >= today && !event.isOverdue
        );
        break;
      case 'overdue':
        this.filteredEvents = this.calendarEvents.filter(event => event.isOverdue);
        break;
      default:
        this.filteredEvents = [...this.calendarEvents];
    }
    
    this.filteredEvents.sort((a, b) => a.date.getTime() - b.date.getTime());
  }

  generateCalendar() {
    const year = this.currentMonth.getFullYear();
    const month = this.currentMonth.getMonth();
    
    const firstDay = new Date(year, month, 1);
    const lastDay = new Date(year, month + 1, 0);
    
    const startDate = new Date(firstDay);
    startDate.setDate(startDate.getDate() - firstDay.getDay());
    
    const endDate = new Date(lastDay);
    endDate.setDate(endDate.getDate() + (6 - lastDay.getDay()));
    
    this.weeks = [];
    let currentDate = new Date(startDate);
    
    while (currentDate <= endDate) {
      const week: { date: Date; events: CalendarEvent[]; isCurrentMonth: boolean }[] = [];
      
      for (let i = 0; i < 7; i++) {
        const date = new Date(currentDate);
        const events = this.calendarEvents.filter(event => this.isSameDay(event.date, date));
        const isCurrentMonth = date.getMonth() === month;
        
        week.push({ date, events, isCurrentMonth });
        currentDate.setDate(currentDate.getDate() + 1);
      }
      
      this.weeks.push(week);
    }
  }

  previousMonth() {
    this.currentMonth = new Date(
      this.currentMonth.getFullYear(),
      this.currentMonth.getMonth() - 1,
      1
    );
    this.generateCalendar();
  }

  nextMonth() {
    this.currentMonth = new Date(
      this.currentMonth.getFullYear(),
      this.currentMonth.getMonth() + 1,
      1
    );
    this.generateCalendar();
  }

  isSameDay(date1: Date, date2: Date): boolean {
    return date1.getDate() === date2.getDate() &&
           date1.getMonth() === date2.getMonth() &&
           date1.getFullYear() === date2.getFullYear();
  }

  isToday(date: Date): boolean {
    const today = new Date();
    return this.isSameDay(date, today);
  }

  getEventColor(event: CalendarEvent): string {
    if (event.isOverdue) return 'danger';
    if (event.type === 'due_date') return 'warning';
    return 'primary';
  }

  getEventIcon(event: CalendarEvent): string {
    if (event.isOverdue) return 'warning';
    if (event.type === 'due_date') return 'calendar';
    return 'cash';
  }

  getMonthName(): string {
    return this.currentMonth.toLocaleString('default', { month: 'long', year: 'numeric' });
  }

  viewDateEvents(date: Date) {
    this.selectedDate = date;
    this.filteredEvents = this.calendarEvents.filter(event => 
      this.isSameDay(event.date, date)
    );
  }

  backToCalendar() {
    this.selectedDate = undefined;
    this.filteredEvents = [...this.calendarEvents];
    this.generateCalendar();
  }

  hasEvents(date: Date): boolean {
    return this.calendarEvents.some(event => this.isSameDay(event.date, date));
  }

  getEventsCount(date: Date): number {
    return this.calendarEvents.filter(event => this.isSameDay(event.date, date)).length;
  }
}