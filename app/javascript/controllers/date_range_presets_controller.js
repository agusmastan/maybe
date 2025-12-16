import { Controller } from "@hotwired/stimulus";

// Handles quick date range presets for filtering
export default class extends Controller {
  static targets = ["startDate", "endDate"];

  selectPreset(event) {
    const preset = event.currentTarget.dataset.preset;
    const { startDate, endDate } = this.calculateDates(preset);

    this.startDateTarget.value = this.formatDate(startDate);
    this.endDateTarget.value = this.formatDate(endDate);

    // Trigger change events to notify other controllers
    this.startDateTarget.dispatchEvent(new Event("change", { bubbles: true }));
    this.endDateTarget.dispatchEvent(new Event("change", { bubbles: true }));
  }

  calculateDates(preset) {
    const today = new Date();
    let startDate, endDate;

    switch (preset) {
      case "1d":
        // Today
        startDate = today;
        endDate = today;
        break;

      case "wtd":
        // Week to Date (from Monday to today)
        startDate = this.getStartOfWeek(today);
        endDate = today;
        break;

      case "7d":
        // Last 7 days
        startDate = new Date(today);
        startDate.setDate(today.getDate() - 6);
        endDate = today;
        break;

      case "mtd":
        // Month to Date
        startDate = new Date(today.getFullYear(), today.getMonth(), 1);
        endDate = today;
        break;

      case "30d":
        // Last 30 days
        startDate = new Date(today);
        startDate.setDate(today.getDate() - 29);
        endDate = today;
        break;

      case "qtd":
        // Quarter to Date
        startDate = this.getStartOfQuarter(today);
        endDate = today;
        break;

      case "ytd":
        // Year to Date
        startDate = new Date(today.getFullYear(), 0, 1);
        endDate = today;
        break;

      case "1y":
        // Last 12 months
        startDate = new Date(today);
        startDate.setFullYear(today.getFullYear() - 1);
        startDate.setDate(startDate.getDate() + 1);
        endDate = today;
        break;

      default:
        startDate = today;
        endDate = today;
    }

    return { startDate, endDate };
  }

  getStartOfWeek(date) {
    const d = new Date(date);
    const day = d.getDay();
    const diff = d.getDate() - day + (day === 0 ? -6 : 1); // Adjust when day is Sunday
    return new Date(d.setDate(diff));
  }

  getStartOfQuarter(date) {
    const quarter = Math.floor(date.getMonth() / 3);
    return new Date(date.getFullYear(), quarter * 3, 1);
  }

  formatDate(date) {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const day = String(date.getDate()).padStart(2, "0");
    return `${year}-${month}-${day}`;
  }
}

