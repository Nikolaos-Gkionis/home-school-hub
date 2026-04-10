import { Controller } from "@hotwired/stimulus"

// Oak-style quiz: one question at a time, segmented progress, Check → feedback → Next until complete.
export default class extends Controller {
  static targets = [
    "questionPhase",
    "completePhase",
    "progressText",
    "progressTrack",
    "headerTitle",
    "questionText",
    "instructionPill",
    "options",
    "hintSection",
    "hintText",
    "hintToggleLabel",
    "feedback",
    "feedbackIcon",
    "feedbackTitle",
    "feedbackSub",
    "checkBtn",
    "nextBtn",
    "footerRow",
  ]

  static values = {
    quizType: String,
    submitUrl: String,
    title: String,
    questions: Array,
  }

  connect() {
    this._buildRounds()
    this.index = 0
    this.phase = "answer" // answer | feedback
    this.selected = new Set()
    this.completedAll = false
    this.hintVisible = true
    this.render()
  }

  _buildRounds() {
    this.rounds = (this.questionsValue || []).map((q) => {
      const answers = Array.isArray(q.answers) ? q.answers : []
      const indexed = answers.map((a, i) => ({ answer: a, origIdx: i }))
      for (let j = indexed.length - 1; j > 0; j--) {
        const k = Math.floor(Math.random() * (j + 1))
        ;[indexed[j], indexed[k]] = [indexed[k], indexed[j]]
      }
      const correctCount = answers.filter((a) => a.distractor === false).length
      const multi = correctCount > 1
      const hint =
        (q.hint && String(q.hint)) ||
        (q.questionHint && String(q.questionHint)) ||
        (q.hintText && String(q.hintText)) ||
        ""
      return { raw: q, ordered: indexed, multi, hint }
    })
  }

  get total() {
    return this.rounds.length
  }

  render() {
    if (this.completedAll || this.total === 0) {
      this.questionPhaseTarget.classList.add("hidden")
      this.completePhaseTarget.classList.remove("hidden")
      return
    }

    this.questionPhaseTarget.classList.remove("hidden")
    this.completePhaseTarget.classList.add("hidden")

    this._renderProgress()
    this.headerTitleTarget.textContent = this.titleValue
    const round = this.rounds[this.index]
    this.questionTextTarget.textContent = round.raw.question || ""
    this.instructionPillTarget.textContent = round.multi ? "Select all that apply" : "Select one answer"

    if (round.hint) {
      this.hintSectionTarget.classList.remove("hidden")
      this.hintTextTarget.textContent = round.hint
      this._updateHintToggle()
    } else {
      this.hintSectionTarget.classList.add("hidden")
    }

    if (this.phase === "answer") {
      this.feedbackTarget.classList.add("hidden")
      this.checkBtnTarget.classList.remove("hidden")
      this.nextBtnTarget.classList.add("hidden")
      this._renderOptionsInteractive(round)
    } else {
      this.feedbackTarget.classList.remove("hidden")
      this.checkBtnTarget.classList.add("hidden")
      this.nextBtnTarget.classList.remove("hidden")
      this._renderFeedbackCopy()
      this._renderOptionsFeedback(round)
    }
  }

  _renderProgress() {
    const n = this.total
    const cur = this.index + 1
    this.progressTextTarget.textContent = `${cur} of ${n}`
    this.progressTrackTarget.replaceChildren()
    for (let i = 0; i < n; i++) {
      const seg = document.createElement("div")
      seg.className =
        i === this.index
          ? "h-2 min-w-0 flex-1 rounded-full bg-neutral-800 dark:bg-neutral-200"
          : "h-2 min-w-0 flex-1 rounded-full bg-sky-200/90 dark:bg-sky-800/50"
      this.progressTrackTarget.appendChild(seg)
    }
  }

  _renderOptionsInteractive(round) {
    this.optionsTarget.replaceChildren()
    const answers = round.raw.answers || []
    round.ordered.forEach(({ answer, origIdx }) => {
      const btn = document.createElement("button")
      btn.type = "button"
      const selected = this.selected.has(origIdx)
      btn.className = this._optionBaseClass(selected)
      btn.addEventListener("click", () => this._pick(origIdx, round.multi))

      const left = document.createElement("span")
      left.className =
        "mt-0.5 flex h-6 w-6 shrink-0 items-center justify-center rounded-full border-2 border-neutral-300 bg-white dark:border-neutral-600 dark:bg-[var(--color-bg)]"
      if (!round.multi) {
        left.innerHTML = selected
          ? '<span class="h-3 w-3 rounded-full bg-neutral-700 dark:bg-neutral-200"></span>'
          : ""
      } else {
        left.innerHTML = selected
          ? '<span class="text-xs font-bold text-emerald-600">✓</span>'
          : ""
      }

      const text = document.createElement("span")
      text.className = "min-w-0 flex-1 text-left text-base font-normal text-neutral-900 dark:text-[var(--color-text)]"
      text.textContent = (answer.content || "").toString().toLowerCase()

      btn.appendChild(left)
      btn.appendChild(text)
      this.optionsTarget.appendChild(btn)
    })
    this.checkBtnTarget.disabled = this.selected.size === 0
  }

  _renderOptionsFeedback(round) {
    this.optionsTarget.replaceChildren()
    const answers = round.raw.answers || []
    const correctSet = new Set(
      answers.map((a, i) => (a.distractor === false ? i : null)).filter((i) => i !== null),
    )
    round.ordered.forEach(({ answer, origIdx }) => {
      const wrap = document.createElement("div")
      const isCorrect = correctSet.has(origIdx)
      const picked = this.selected.has(origIdx)
      let boxClass =
        "flex w-full items-center gap-3 rounded-2xl border-2 bg-white p-4 dark:bg-[var(--color-surface)] "
      if (isCorrect) {
        boxClass += "border-emerald-500 ring-2 ring-emerald-400/40"
      } else if (picked && !isCorrect) {
        boxClass += "border-red-400/70"
      } else {
        boxClass += "border-neutral-200 dark:border-[var(--color-border)]"
      }

      wrap.className = boxClass

      const left = document.createElement("span")
      left.className =
        "flex h-6 w-6 shrink-0 items-center justify-center rounded-full border-2 border-neutral-400 dark:border-neutral-500"
      if (round.multi) {
        left.innerHTML = picked
          ? isCorrect
            ? '<span class="text-emerald-600">✓</span>'
            : '<span class="text-red-500">✕</span>'
          : isCorrect
            ? '<span class="text-emerald-600">✓</span>'
            : ""
      } else {
        left.innerHTML = picked || isCorrect ? '<span class="h-3 w-3 rounded-full bg-neutral-700 dark:bg-neutral-200"></span>' : ""
      }

      const text = document.createElement("span")
      text.className = "min-w-0 flex-1 text-left text-base text-neutral-900 dark:text-[var(--color-text)]"
      text.textContent = (answer.content || "").toString().toLowerCase()

      if (isCorrect) {
        const tick = document.createElement("span")
        tick.className = "text-xl text-emerald-600"
        tick.textContent = "✓"
        tick.setAttribute("aria-hidden", "true")
        wrap.appendChild(left)
        wrap.appendChild(text)
        wrap.appendChild(tick)
      } else {
        wrap.appendChild(left)
        wrap.appendChild(text)
      }

      this.optionsTarget.appendChild(wrap)
    })
  }

  _optionBaseClass(selected) {
    const base =
      "flex w-full items-center gap-3 rounded-2xl border-2 border-neutral-200 bg-white p-4 text-left transition hover:border-emerald-300/80 dark:border-[var(--color-border)] dark:bg-[var(--color-surface)]"
    return selected ? `${base} border-emerald-400 ring-2 ring-emerald-400/30` : base
  }

  _pick(origIdx, multi) {
    if (this.phase !== "answer") return
    if (multi) {
      if (this.selected.has(origIdx)) this.selected.delete(origIdx)
      else this.selected.add(origIdx)
    } else {
      this.selected = new Set([origIdx])
    }
    const round = this.rounds[this.index]
    this._renderOptionsInteractive(round)
    this.checkBtnTarget.disabled = this.selected.size === 0
  }

  _renderFeedbackCopy() {
    const ok = this.lastCorrect === true
    this.feedbackIconTarget.textContent = ok ? "✓" : "✕"
    this.feedbackIconTarget.className = ok ? "text-2xl text-emerald-600" : "text-2xl text-red-500"
    this.feedbackTitleTarget.textContent = ok ? "Correct" : "Not quite"
    this.feedbackTitleTarget.className = ok ? "text-lg font-bold text-emerald-700 dark:text-emerald-400" : "text-lg font-bold text-red-600 dark:text-red-400"
    this.feedbackSubTarget.textContent = ok ? "Well done!" : "Keep going — check the highlighted answer and try the next one."
    this.feedbackSubTarget.classList.remove("hidden")
    if (ok) {
      this.feedbackSubTarget.classList.remove("hidden")
    }
  }

  async checkAnswer(event) {
    event?.preventDefault()
    if (this.phase !== "answer" || this.selected.size === 0) return

    this.checkBtnTarget.disabled = true
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    const fd = new FormData()
    fd.append("quiz_type", this.quizTypeValue)
    fd.append("question_index", String(this.index))
    this.selected.forEach((idx) => fd.append("answer_indices[]", String(idx)))

    try {
      const res = await fetch(this.submitUrlValue, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": token || "",
        },
        body: fd,
        credentials: "same-origin",
      })
      if (!res.ok) {
        this.checkBtnTarget.disabled = false
        return
      }
      const data = await res.json()
      this.lastCorrect = data.correct === true
      this.phase = "feedback"
      this.render()
    } catch {
      this.checkBtnTarget.disabled = false
    }
  }

  nextQuestion(event) {
    event?.preventDefault()
    if (this.phase !== "feedback") return

    if (this.index + 1 >= this.total) {
      this.completedAll = true
      this.render()
      return
    }
    this.index += 1
    this.phase = "answer"
    this.selected = new Set()
    this.render()
  }

  headerBack(event) {
    event?.preventDefault()
    if (this.phase === "feedback") return

    if (this.index === 0) {
      this.dispatch("exit-to-overview", { bubbles: true })
      return
    }
    this.index -= 1
    this.selected = new Set()
    this.phase = "answer"
    this.render()
  }

  toggleHint(event) {
    event?.preventDefault()
    if (!this.hasHintTextTarget || !this.hasHintToggleLabelTarget) return
    this.hintVisible = !this.hintVisible
    this._updateHintToggle()
  }

  _updateHintToggle() {
    if (!this.hasHintTextTarget || !this.hasHintToggleLabelTarget) return
    this.hintTextTarget.classList.toggle("hidden", !this.hintVisible)
    this.hintToggleLabelTarget.textContent = this.hintVisible ? "Close hint" : "Show hint"
  }

  exitToOverview(event) {
    event?.preventDefault()
    this.dispatch("exit-to-overview", { bubbles: true })
  }
}
