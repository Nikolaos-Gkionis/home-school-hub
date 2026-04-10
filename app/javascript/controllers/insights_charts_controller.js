import { Controller } from "@hotwired/stimulus"

// Chart.js is loaded only when this controller connects (insights page).
export default class extends Controller {
  static targets = ["weekCanvas", "subjectCanvas", "learnerCanvas"]
  static values = {
    weekLabels: Array,
    weekCounts: Array,
    subjectLabels: Array,
    subjectCounts: Array,
    learnerRows: Array,
  }

  async connect() {
    const { Chart, registerables } = await import("chart.js")
    Chart.register(...registerables)
    this.Chart = Chart

    const text = this.cssVar("--color-text") || "#e2e8f0"
    const muted = this.cssVar("--color-text-muted") || "#94a3b8"
    const accent = this.cssVar("--color-accent") || "#a78bfa"
    const border = this.cssVar("--color-border") || "rgba(167, 139, 250, 0.25)"

    this.accentRgb = accent
    this.chartTextColor = text
    this.chartMutedColor = muted
    this.chartBorderColor = border
    this.bodyFontFamily =
      getComputedStyle(document.body).fontFamily || "system-ui, sans-serif"

    if (this.hasWeekCanvasTarget && this.weekLabelsValue.length > 0) {
      this.weekChart = this.buildWeekChart()
    }
    if (this.hasSubjectCanvasTarget && this.subjectLabelsValue.length > 0) {
      this.subjectChart = this.buildSubjectChart()
    }
    if (
      this.hasLearnerCanvasTarget &&
      Array.isArray(this.learnerRowsValue) &&
      this.learnerRowsValue.length > 0
    ) {
      this.learnerChart = this.buildLearnerChart()
    }
  }

  disconnect() {
    this.weekChart?.destroy()
    this.subjectChart?.destroy()
    this.learnerChart?.destroy()
  }

  cssVar(name) {
    return getComputedStyle(document.documentElement).getPropertyValue(name).trim()
  }

  buildWeekChart() {
    const max = Math.max(1, ...this.weekCountsValue.map((n) => Number(n) || 0))
    return new this.Chart(this.weekCanvasTarget, {
      type: "bar",
      data: {
        labels: this.weekLabelsValue.map((d) => this.shortWeekLabel(d)),
        datasets: [
          {
            label: "Lessons completed",
            data: this.weekCountsValue.map((n) => Number(n) || 0),
            backgroundColor: this.withAlpha(this.accentRgb, 0.55),
            borderColor: this.accentRgb,
            borderWidth: 1,
            borderRadius: 4,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        font: { family: this.bodyFontFamily },
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              title: (items) => {
                const i = items[0]?.dataIndex
                return i != null ? String(this.weekLabelsValue[i]) : ""
              },
            },
          },
        },
        scales: {
          x: {
            grid: { color: this.withAlpha(this.chartMutedColor, 0.15) },
            ticks: { color: this.chartMutedColor, maxRotation: 45, minRotation: 0 },
          },
          y: {
            beginAtZero: true,
            suggestedMax: max,
            grid: { color: this.withAlpha(this.chartMutedColor, 0.15) },
            ticks: {
              color: this.chartMutedColor,
              precision: 0,
            },
          },
        },
      },
    })
  }

  buildSubjectChart() {
    return new this.Chart(this.subjectCanvasTarget, {
      type: "bar",
      data: {
        labels: this.subjectLabelsValue.map((s) => this.truncate(s, 28)),
        datasets: [
          {
            label: "Completions",
            data: this.subjectCountsValue.map((n) => Number(n) || 0),
            backgroundColor: this.withAlpha(this.accentRgb, 0.5),
            borderColor: this.accentRgb,
            borderWidth: 1,
            borderRadius: 4,
          },
        ],
      },
      options: {
        indexAxis: "y",
        responsive: true,
        maintainAspectRatio: false,
        font: { family: this.bodyFontFamily },
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              title: (items) => {
                const i = items[0]?.dataIndex
                return i != null ? String(this.subjectLabelsValue[i]) : ""
              },
            },
          },
        },
        scales: {
          x: {
            beginAtZero: true,
            grid: { color: this.withAlpha(this.chartMutedColor, 0.15) },
            ticks: { color: this.chartMutedColor, precision: 0 },
          },
          y: {
            grid: { display: false },
            ticks: { color: this.chartMutedColor },
          },
        },
      },
    })
  }

  buildLearnerChart() {
    const rows = this.learnerRowsValue
    const labels = rows.map((r) => this.truncate(r.label || r.email || "Learner", 24))
    const lessons = rows.map((r) => Number(r.lessons_completed) || 0)
    const sections = rows.map((r) => Number(r.sections_explored) || 0)
    const quizzes = rows.map((r) => Number(r.quiz_attempts) || 0)

    return new this.Chart(this.learnerCanvasTarget, {
      type: "bar",
      data: {
        labels,
        datasets: [
          {
            label: "Lessons done",
            data: lessons,
            backgroundColor: this.withAlpha(this.accentRgb, 0.75),
            borderColor: this.accentRgb,
            borderWidth: 1,
            borderRadius: 3,
          },
          {
            label: "Sections viewed",
            data: sections,
            backgroundColor: this.withAlpha(this.chartMutedColor, 0.45),
            borderColor: this.withAlpha(this.chartMutedColor, 0.8),
            borderWidth: 1,
            borderRadius: 3,
          },
          {
            label: "Quiz attempts",
            data: quizzes,
            backgroundColor: this.withAlpha("#fbbf24", 0.35),
            borderColor: "#fbbf24",
            borderWidth: 1,
            borderRadius: 3,
          },
        ],
      },
      options: {
        indexAxis: "y",
        responsive: true,
        maintainAspectRatio: false,
        font: { family: this.bodyFontFamily },
        plugins: {
          legend: {
            position: "bottom",
            labels: {
              color: this.chartMutedColor,
              boxWidth: 12,
              padding: 12,
              font: { family: this.bodyFontFamily },
            },
          },
          tooltip: {
            callbacks: {
              title: (items) => {
                const i = items[0]?.dataIndex
                return i != null ? String(rows[i].label || rows[i].email || "") : ""
              },
            },
          },
        },
        scales: {
          x: {
            beginAtZero: true,
            grid: { color: this.withAlpha(this.chartMutedColor, 0.12) },
            ticks: { color: this.chartMutedColor, precision: 0 },
          },
          y: {
            grid: { display: false },
            ticks: { color: this.chartMutedColor },
          },
        },
      },
    })
  }

  shortWeekLabel(isoDate) {
    const s = String(isoDate)
    const d = new Date(s)
    if (!Number.isNaN(d.getTime())) {
      return d.toLocaleDateString(undefined, { month: "short", day: "numeric" })
    }
    return s.length > 8 ? s.slice(-8) : s
  }

  truncate(str, max) {
    const t = String(str)
    return t.length <= max ? t : `${t.slice(0, max - 1)}…`
  }

  /** Accepts hex (#rgb) or rgb()/hsl() and returns rgba for Chart.js fills */
  withAlpha(color, alpha) {
    const c = String(color).trim()
    if (c.startsWith("#") && (c.length === 7 || c.length === 4)) {
      let r, g, b
      if (c.length === 7) {
        r = parseInt(c.slice(1, 3), 16)
        g = parseInt(c.slice(3, 5), 16)
        b = parseInt(c.slice(5, 7), 16)
      } else {
        r = parseInt(c[1] + c[1], 16)
        g = parseInt(c[2] + c[2], 16)
        b = parseInt(c[3] + c[3], 16)
      }
      return `rgba(${r},${g},${b},${alpha})`
    }
    const m = c.match(/rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)/i)
    if (m) return `rgba(${m[1]},${m[2]},${m[3]},${alpha})`
    return c
  }
}
