;; Experiment Coordination Contract
;; Manages vacuum energy experiments and their lifecycle

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_EXPERIMENT_EXISTS (err u201))
(define-constant ERR_EXPERIMENT_NOT_FOUND (err u202))
(define-constant ERR_INVALID_STATUS (err u203))
(define-constant ERR_FACILITY_NOT_VERIFIED (err u204))

;; Experiment status types
(define-constant STATUS_PROPOSED u0)
(define-constant STATUS_APPROVED u1)
(define-constant STATUS_ACTIVE u2)
(define-constant STATUS_COMPLETED u3)
(define-constant STATUS_CANCELLED u4)

;; Data structure for experiments
(define-map experiments
  { experiment-id: uint }
  {
    title: (string-ascii 200),
    facility-id: uint,
    researcher: principal,
    status: uint,
    start-date: uint,
    end-date: uint,
    energy-level: uint,
    safety-clearance: uint,
    results-hash: (optional (buff 32))
  }
)

(define-data-var experiment-counter uint u0)

;; Reference to facility verification contract
(define-trait facility-verification-trait
  (
    (is-facility-verified (uint) (response bool uint))
  )
)

;; Propose a new experiment
(define-public (propose-experiment
  (title (string-ascii 200))
  (facility-id uint)
  (energy-level uint)
  (duration uint)
  (facility-contract <facility-verification-trait>)
)
  (let ((experiment-id (+ (var-get experiment-counter) u1)))
    (asserts! (is-none (map-get? experiments { experiment-id: experiment-id })) ERR_EXPERIMENT_EXISTS)
    (asserts! (unwrap! (contract-call? facility-contract is-facility-verified facility-id) ERR_FACILITY_NOT_VERIFIED) ERR_FACILITY_NOT_VERIFIED)
    (map-set experiments
      { experiment-id: experiment-id }
      {
        title: title,
        facility-id: facility-id,
        researcher: tx-sender,
        status: STATUS_PROPOSED,
        start-date: u0,
        end-date: u0,
        energy-level: energy-level,
        safety-clearance: u0,
        results-hash: none
      }
    )
    (var-set experiment-counter experiment-id)
    (ok experiment-id)
  )
)

;; Approve experiment (admin only)
(define-public (approve-experiment (experiment-id uint) (safety-clearance uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? experiments { experiment-id: experiment-id })
      experiment-data
      (begin
        (map-set experiments
          { experiment-id: experiment-id }
          (merge experiment-data {
            status: STATUS_APPROVED,
            safety-clearance: safety-clearance
          })
        )
        (ok true)
      )
      ERR_EXPERIMENT_NOT_FOUND
    )
  )
)

;; Start experiment
(define-public (start-experiment (experiment-id uint) (duration uint))
  (match (map-get? experiments { experiment-id: experiment-id })
    experiment-data
    (begin
      (asserts! (is-eq (get researcher experiment-data) tx-sender) ERR_UNAUTHORIZED)
      (asserts! (is-eq (get status experiment-data) STATUS_APPROVED) ERR_INVALID_STATUS)
      (map-set experiments
        { experiment-id: experiment-id }
        (merge experiment-data {
          status: STATUS_ACTIVE,
          start-date: block-height,
          end-date: (+ block-height duration)
        })
      )
      (ok true)
    )
    ERR_EXPERIMENT_NOT_FOUND
  )
)

;; Complete experiment with results
(define-public (complete-experiment (experiment-id uint) (results-hash (buff 32)))
  (match (map-get? experiments { experiment-id: experiment-id })
    experiment-data
    (begin
      (asserts! (is-eq (get researcher experiment-data) tx-sender) ERR_UNAUTHORIZED)
      (asserts! (is-eq (get status experiment-data) STATUS_ACTIVE) ERR_INVALID_STATUS)
      (map-set experiments
        { experiment-id: experiment-id }
        (merge experiment-data {
          status: STATUS_COMPLETED,
          results-hash: (some results-hash)
        })
      )
      (ok true)
    )
    ERR_EXPERIMENT_NOT_FOUND
  )
)

;; Get experiment information
(define-read-only (get-experiment (experiment-id uint))
  (map-get? experiments { experiment-id: experiment-id })
)

;; Get total number of experiments
(define-read-only (get-experiment-count)
  (var-get experiment-counter)
)
