## Scripts

| File | Purpose |
| --- | --- |
| `blsa_hg_age.stan` | Hierarchical model of handgrip vs age. Fit to BLSA to obtain the parameters the simulation is grounded in. |
| `sim_design.R` | Simulates trials under three designs (two-arm, split-body, multi-outcome) and estimates detectability across sample size, number of measurements and follow-up duration. Also checks the Stan models against `lme4` equivalents. |
| `1_two_arm_LMM.stan` | Two-arm model: treatment effect on slope, between individuals. |
| `2_splitbody_LMM.stan` | Split-body model: treatment effect on slope, dominant vs non-dominant hand within individual. |
| `figures.R` | Manuscript figures 1–4. |

## Requirements

R ≥ 4.0 with `ggplot2` (≥ 3.5.0, for the `axes` argument to `facet_grid`),
`lme4`, `lmerTest`, `cowplot`, `viridis`, `parallel`, and a Stan interface.

## Data

Not included in this repository:

- `blsa_hg_post.csv` — posterior draws from `blsa_hg_age.stan` fit to BLSA.
- `data/amyloid_pet_digitized.csv` — amyloid-PET values digitized from
  published figures: Sims et al. 2023 (*JAMA*, TRAILBLAZER-ALZ 2, Fig 3A) and
  van Dyck et al. 2023 (*NEJM*, Clarity AD, Fig 2B).