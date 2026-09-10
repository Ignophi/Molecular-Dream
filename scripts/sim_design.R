library("ggplot2")
library("lme4")
library("lmerTest")
library("cowplot")
library("parallel")

age_mean <- 81.48 # mean(df_blsa$age)
cat("Mean age (centering value):", round(age_mean, 2), "\n")

# -----------------------------------------------------------------------------
# Simulation parameters — posterior means
#
# Rather than propagating full posterior uncertainty into the simulation, we
# use the posterior mean of each hyperparameter as a fixed value. This is
# sufficient given that the goal of the simulation is to evaluate study design
# properties under plausible parameter values, not to make claims about the
# exact values themselves. The BLSA estimates are used to ground the simulation
# in realistic ranges, not to assert they are the true population parameters.
# -----------------------------------------------------------------------------
df_post <- read.csv("blsa_hg_post.csv", header = T)

a_mean    <- mean(df_post[, "a_mean"])
a_sd      <- mean(df_post[, "a_sd"])
beta_mean <- mean(df_post[, "beta_mean"])
beta_sd   <- mean(df_post[, "beta_sd"])

# -----------------------------------------------------------------------------
# Within-person measurement noise (sigma)
#
# Sigma captures the variability in handgrip measurements within the same
# individual at a given visit — i.e. how much a measurement would be expected
# to vary if the same person were tested twice under the same conditions on
# the same day. This is distinct from between-session variability, which
# additionally absorbs biological fluctuations between visits.
#
# No short-interval repeated measurements exist in the BLSA data (minimum gap
# ~279 days), so sigma cannot be estimated from the data directly. The residual
# from the hierarchical model (~3.5 kg, CV ~10%) exceeds pure within-session
# noise as it absorbs genuine biological fluctuations not captured by a linear
# trajectory. We therefore base sigma on literature reporting within-session
# CV for handgrip in older adults of ~5% (Bohannon & Schaubert, 2005;
# Serrien et al., 2022), giving sigma = 0.05 * a_mean ~ 1.65 kg. This
# represents a realistic measurement noise floor under controlled trial
# conditions and produces more conservative power estimates than the model
# residual would.
# -----------------------------------------------------------------------------
sigmas <- c(
    "Within-session_CV_0.05"  = 0.05 * a_mean,
    "BLSA_residual_0.1" = mean(df_post[, "sigma"])
)

# -----------------------------------------------------------------------------
# Simulation function
# -----------------------------------------------------------------------------
sim_trial <- function(n, delta, times, a_mean, a_sd,
                      beta_mean, beta_sd, sigma, age_mean,
                      type = "systemic",
                      comparison = "between",
                      lat_offset = 0.10, lat_sd = 2) {

    # For each individual, sample their characteristics and generate
    # their handgrip trajectory over the trial period
    do.call(rbind, lapply(1:n, function(i) {

        # Each individual has a baseline handgrip strength at the mean age
        # of the sample. We assume this varies across individuals following
        # a gaussian distribution, with mean and spread estimated from the BLSA.
        alpha <- rnorm(1, mean = a_mean, sd = a_sd)

        # Each individual has their own rate of handgrip decline per year.
        # We assume this also varies across individuals, with mean
        # and spread estimated from the BLSA. Importantly, we assume that
        # baseline strength and rate of decline are independent — i.e. knowing
        # someone's baseline tells us nothing about how fast they will decline.
        # This is supported by the BLSA data, which showed only a weak tendency 
        # for the two to be related (correlation ~0.11), insufficient to justify 
        # a more complex joint model given the objectives of the simulation.
        beta  <- rnorm(1, mean = beta_mean, sd = beta_sd)

        # Each individual enters the trial at a different age, sampled
        # uniformly between 65 and 80. This reflects realistic recruitment
        # in gerontological trials and means individuals start the trial
        # at different points on their decline trajectory.
        age   <- runif(1, min = 65, max = 80)

        # "between": participants are split into control and treatment groups —
        # the comparison is between individuals.
        # "within": all participants are treated — the comparison is within
        # individuals, using the non-dominant hand as the within-person control.
        grp <- if (comparison == "within") "treat" else
                   ifelse(i <= round(n / 2), "ctl", "treat")

        # The intervention slows the rate of decline (delta > 0) for treated
        # individuals.
        # "local": intervention acts only on the treated hand (dominant).
        # The non-dominant hand is unaffected regardless of group assignment.
        # "systemic": intervention acts globally, both hands of treated
        # individuals benefit equally.
        d_dom  <- ifelse(grp == "treat", delta, 0)
        d_ndom <- if (type == "local") 0 else ifelse(grp == "treat", delta, 0)

        # The non-dominant hand is assumed to be weaker than the dominant hand
        # by a fixed proportion (lat_offset = 10%), with additional individual-
        # level variation around this offset (lat_sd = 2 kg). Both values are
        # based on normative laterality data from the literature. The rate of
        # decline (beta) is assumed to be the same for both hands. 
        # This is a simplifying assumption not directly supported by data,
        # adopted here to illustrate the concept of multi-outcome designs
        # rather than to make realistic claims about bilateral decline.
        alpha_ndom <- alpha * (1 - lat_offset) + rnorm(1, 0, lat_sd)

        # Generate the handgrip trajectory for each hand over the trial.
        # The trajectory has three components:
        #   1. Where the individual starts relative to the mean age (age offset)
        #   2. How they change over the trial period (slope + intervention)
        #   3. Random measurement noise at each visit (sigma)
        hg_dom  <- alpha + beta * (age - age_mean) +
                   (beta + d_dom) * times +
                   rnorm(length(times), 0, sigma)

        hg_ndom <- alpha_ndom + beta * (age - age_mean) +
                   (beta + d_ndom) * times +
                   rnorm(length(times), 0, sigma)

        data.frame(
            id           = paste0(i, "_", grp),
            group        = grp,
            hand         = rep(c("dom", "ndom"), each = length(times)),
            time         = rep(times, 2),
            handgrip     = c(hg_dom, hg_ndom),
            age_baseline = age,
            n            = n,
            delta        = delta,
            type         = type,
            comparison   = comparison,
            lat_offset   = lat_offset,
            lat_sd       = lat_sd
        )
    }))
}

# -----------------------------------------------------------------------------
# analyze_trial
#
# Generates a single simulated trial and returns p-values for each analysis
# strategy applicable to the given type and comparison.
# -----------------------------------------------------------------------------
analyze_trial <- function(n, delta, t_sample, a_mean, a_sd,
                          beta_mean, beta_sd, sigma, age_mean,
                          type       = "systemic",
                          comparison = "between",
                          lat_offset = 0.10, lat_sd = 2) {

    if (comparison == "within" & type == "systemic")
        stop("combination of within-comparison and systemic type is not meaningful")

    t_start <- min(t_sample)
    t_end   <- max(t_sample)

    df       <- sim_trial(n, delta, t_sample, a_mean, a_sd,
                          beta_mean, beta_sd, sigma, age_mean,
                          type = type, comparison = comparison,
                          lat_offset = lat_offset, lat_sd = lat_sd)
    df$group <- factor(df$group, levels = c("ctl", "treat"))

    out <- c()

    if (comparison == "between") {
        df_dom     <- df[df$hand == "dom", ]
        df_ctl_dom <- df_dom[df_dom$group == "ctl", ]
        df_trt_dom <- df_dom[df_dom$group == "treat", ]

        # Endpoint t-test on dominant hand
        p_endpoint <- t.test(df_trt_dom[df_trt_dom$time == t_end, "handgrip"],
                             df_ctl_dom[df_ctl_dom$time == t_end, "handgrip"])$p.value

        # Change score t-test on dominant hand
        change_ctl <- df_ctl_dom[df_ctl_dom$time == t_end, "handgrip"] -
                      df_ctl_dom[df_ctl_dom$time == t_start, "handgrip"]
        change_trt <- df_trt_dom[df_trt_dom$time == t_end, "handgrip"] -
                      df_trt_dom[df_trt_dom$time == t_start, "handgrip"]
        p_change_score <- t.test(change_trt, change_ctl)$p.value

        # LMM on dominant hand
        fit_lmm   <- suppressWarnings(suppressMessages(
                         lmer(handgrip ~ time + time:group + (1 | id) + (0 + time | id),
                              data = df_dom)))
        coefs_lmm <- as.data.frame(coef(summary(fit_lmm)))
        p_lmm     <- if (!"Pr(>|t|)" %in% colnames(coefs_lmm)) NA else
                         coefs_lmm["time:grouptreat", "Pr(>|t|)"]

        out <- c(out, endpoint = p_endpoint, change_score = p_change_score,
                 lmm = p_lmm)

        # Multi-outcome LMM pooling both hands, systemic type only
        if (type == "systemic") {
            # Multi-outcome LMM
            fit_multi   <- suppressWarnings(suppressMessages(
                            lmer(handgrip ~ time + hand + time:group +
                                    (1 | id) + (0 + time | id) + (1 | id:hand),
                                    data = df)))
            coefs_multi <- as.data.frame(coef(summary(fit_multi)))
            p_multi     <- if (!"Pr(>|t|)" %in% colnames(coefs_multi)) NA else
                            coefs_multi["time:grouptreat", "Pr(>|t|)"]
            out <- c(out, multi_outcome = p_multi)

            # Multi-outcome change score: average change across both hands per
            # individual then compare between groups
            df_end   <- df[df$time == t_end, ]
            df_start <- df[df$time == t_start, ]

            change_dom  <- df_end[df_end$hand == "dom",  "handgrip"] -
                        df_start[df_start$hand == "dom",  "handgrip"]
            change_ndom <- df_end[df_end$hand == "ndom", "handgrip"] -
                        df_start[df_start$hand == "ndom", "handgrip"]

            change_avg <- (change_dom + change_ndom) / 2
            grp        <- df_end[df_end$hand == "dom", "group"]

            p_multi_cs <- t.test(change_avg[grp == "treat"],
                                change_avg[grp == "ctl"])$p.value
            out <- c(out, multi_outcome_cs = p_multi_cs)
        }
    }

    # Split-body: within-person comparison between hands, local type only
    if (comparison == "within" & type == "local") {

        df$hand <- factor(df$hand, levels = c("dom", "ndom"))

        # Paired change-score: difference in change between hands per individual
        change_dom  <- df[df$hand == "dom"  & df$time == t_end, "handgrip"] -
                    df[df$hand == "dom"  & df$time == t_start, "handgrip"]
        change_ndom <- df[df$hand == "ndom" & df$time == t_end, "handgrip"] -
                    df[df$hand == "ndom" & df$time == t_start, "handgrip"]
        p_split_cs <- t.test(change_dom - change_ndom)$p.value

        # Split-body LMM: tests whether slopes differ between hands across all
        # timepoints. time:handndom is the treatment effect — dominant hand is
        # treated, non-dominant is control, so hand and treatment are confounded
        # by design.
        fit_split   <- suppressWarnings(suppressMessages(
                        lmer(handgrip ~ time + hand + time:hand +
                                (1 | id) + (0 + time | id) + (1 | id:hand),
                                data = df)))
        coefs_split <- as.data.frame(coef(summary(fit_split)))
        p_split_lmm <- if (!"Pr(>|t|)" %in% colnames(coefs_split)) NA else
                        coefs_split["time:handndom", "Pr(>|t|)"]

        out <- c(out, split_body_cs  = p_split_cs,
                    split_body_lmm = p_split_lmm)
    }

    out
}

# -----------------------------------------------------------------------------
# detectability
#
# Runs analyze_trial n_sim times and returns the proportion of runs in which
# each analysis strategy detects the effect (p < 0.05).
# -----------------------------------------------------------------------------
detectability <- function(n_sim, n, delta, t_sample, a_mean, a_sd,
                          beta_mean, beta_sd, sigma, age_mean,
                          type       = "systemic",
                          comparison = "between",
                          lat_offset = 0.10, lat_sd = 2) {

    ps <- replicate(n_sim, analyze_trial(n, delta, t_sample,
                                         a_mean, a_sd, beta_mean, beta_sd,
                                         sigma, age_mean,
                                         type = type, comparison = comparison,
                                         lat_offset = lat_offset,
                                         lat_sd = lat_sd))

    # ps may be a vector (single strategy) or matrix (multiple strategies)
    if (is.null(dim(ps))) {
        setNames(mean(ps < 0.05, na.rm = TRUE), names(ps)[1])
    } else {
        apply(ps < 0.05, 1, mean, na.rm = TRUE)
    }
}


# =============================================================================
# Detectability across design conditions — 3 designs x 3 conditions
# =============================================================================
n_cores <- detectCores() - 1

n_sim           <- 1000
n_default       <- 50
t_sample_default <- c(0, 1, 2)
delta           <- (0.2 * a_sd) / max(t_sample_default)

n_values        <- seq(50, 200, by = 10)
n_tp_values     <- 3:8
followup_values <- seq(2, 8, by = 0.5)

for(s in names(sigmas)) {
    sigma <- sigmas[[s]]
    # -----------------------------------------------------------------------------
    # Two-arm — endpoint, change_score, lmm (between, systemic, dominant hand)
    # -----------------------------------------------------------------------------
    res_twoarm <- do.call(rbind, c(
        mclapply(n_values, function(n) {
            d <- detectability(n_sim, n, delta, t_sample_default,
                            a_mean, a_sd, beta_mean, beta_sd,
                            sigma, age_mean, type = "systemic",
                            comparison = "between")
            data.frame(design = "Two-arm", condition = "Sample size (n)",
                    value = n,
                    endpoint     = d["endpoint"],
                    change_score = d["change_score"],
                    lmm          = d["lmm"])
        }, mc.cores = n_cores),
        mclapply(n_tp_values, function(n_tp) {
            d <- detectability(n_sim, n_default, delta,
                            seq(0, 2, length.out = n_tp),
                            a_mean, a_sd, beta_mean, beta_sd,
                            sigma, age_mean, type = "systemic",
                            comparison = "between")
            data.frame(design = "Two-arm", condition = "Number of timepoints",
                    value = n_tp,
                    endpoint     = d["endpoint"],
                    change_score = d["change_score"],
                    lmm          = d["lmm"])
        }, mc.cores = n_cores),
        mclapply(followup_values, function(fu) {
            d <- detectability(n_sim, n_default, delta,
                            seq(0, fu, length.out = 3),
                            a_mean, a_sd, beta_mean, beta_sd,
                            sigma, age_mean, type = "systemic",
                            comparison = "between")
            data.frame(design = "Two-arm", condition = "Follow-up duration (years)",
                    value = fu,
                    endpoint     = d["endpoint"],
                    change_score = d["change_score"],
                    lmm          = d["lmm"])
        }, mc.cores = n_cores)
    ))

    # -----------------------------------------------------------------------------
    # Split-body — paired change-score and LMM (within, local)
    # -----------------------------------------------------------------------------
    res_split <- do.call(rbind, c(
        mclapply(n_values, function(n) {
            d <- detectability(n_sim, n, delta, t_sample_default,
                            a_mean, a_sd, beta_mean, beta_sd,
                            sigma, age_mean, type = "local",
                            comparison = "within")
            data.frame(design = "Split-body", condition = "Sample size (n)",
                    value = n,
                    split_body_cs  = d["split_body_cs"],
                    split_body_lmm = d["split_body_lmm"])
        }, mc.cores = n_cores),
        mclapply(n_tp_values, function(n_tp) {
            d <- detectability(n_sim, n_default, delta,
                            seq(0, 2, length.out = n_tp),
                            a_mean, a_sd, beta_mean, beta_sd,
                            sigma, age_mean, type = "local",
                            comparison = "within")
            data.frame(design = "Split-body", condition = "Number of timepoints",
                    value = n_tp,
                    split_body_cs  = d["split_body_cs"],
                    split_body_lmm = d["split_body_lmm"])
        }, mc.cores = n_cores),
        mclapply(followup_values, function(fu) {
            d <- detectability(n_sim, n_default, delta,
                            seq(0, fu, length.out = 3),
                            a_mean, a_sd, beta_mean, beta_sd,
                            sigma, age_mean, type = "local",
                            comparison = "within")
            data.frame(design = "Split-body", condition = "Follow-up duration (years)",
                    value = fu,
                    split_body_cs  = d["split_body_cs"],
                    split_body_lmm = d["split_body_lmm"])
        }, mc.cores = n_cores)
    ))

    # -----------------------------------------------------------------------------
    # Multi-outcome — LMM and change score (between, systemic, both hands)
    # -----------------------------------------------------------------------------
    res_multi <- do.call(rbind, c(
        mclapply(n_values, function(n) {
            d <- detectability(n_sim, n, delta, t_sample_default,
                            a_mean, a_sd, beta_mean, beta_sd,
                            sigma, age_mean, type = "systemic",
                            comparison = "between")
            data.frame(design = "Multi-outcome", condition = "Sample size (n)",
                    value = n,
                    multi_outcome    = unname(d["multi_outcome"]),
                    multi_outcome_cs = unname(d["multi_outcome_cs"]))
        }, mc.cores = n_cores),
        mclapply(n_tp_values, function(n_tp) {
            d <- detectability(n_sim, n_default, delta,
                            seq(0, 2, length.out = n_tp),
                            a_mean, a_sd, beta_mean, beta_sd,
                            sigma, age_mean, type = "systemic",
                            comparison = "between")
            data.frame(design = "Multi-outcome", condition = "Number of timepoints",
                    value = n_tp,
                    multi_outcome    = unname(d["multi_outcome"]),
                    multi_outcome_cs = unname(d["multi_outcome_cs"]))
        }, mc.cores = n_cores),
        mclapply(followup_values, function(fu) {
            d <- detectability(n_sim, n_default, delta,
                            seq(0, fu, length.out = 3),
                            a_mean, a_sd, beta_mean, beta_sd,
                            sigma, age_mean, type = "systemic",
                            comparison = "between")
            data.frame(design = "Multi-outcome", condition = "Follow-up duration (years)",
                    value = fu,
                    multi_outcome    = unname(d["multi_outcome"]),
                    multi_outcome_cs = unname(d["multi_outcome_cs"]))
        }, mc.cores = n_cores)
    ))

    # -----------------------------------------------------------------------------
    # Combine and plot
    # -----------------------------------------------------------------------------
    res_twoarm_long <- reshape(res_twoarm,
                            varying   = c("endpoint", "change_score", "lmm"),
                            v.names   = "detect",
                            timevar   = "method",
                            times     = c("Endpoint t-test",
                                            "Change score t-test",
                                            "LMM"),
                            direction = "long")
    res_twoarm_long$id <- NULL

    res_split_long <- reshape(res_split,
                            varying   = c("split_body_cs", "split_body_lmm"),
                            v.names   = "detect",
                            timevar   = "method",
                            times     = c("Split-body change-score",
                                            "Split-body LMM"),
                            direction = "long")
    res_split_long$id <- NULL

    res_multi_long <- reshape(res_multi,
                            varying   = c("multi_outcome", "multi_outcome_cs"),
                            v.names   = "detect",
                            timevar   = "method",
                            times     = c("Multi-outcome LMM",
                                            "Multi-outcome change-score"),
                            direction = "long")
    res_multi_long$id <- NULL

    detect_all <- rbind(res_twoarm_long, res_split_long, res_multi_long)

    detect_all$design <- factor(detect_all$design,
                                levels = c("Two-arm",
                                            "Split-body",
                                            "Multi-outcome"))
    detect_all$condition <- factor(detect_all$condition,
                                    levels = c("Sample size (n)",
                                            "Number of timepoints",
                                            "Follow-up duration (years)"))
    
    detect_all$sigma       <- sigma
    detect_all$sigma_label <- s
    detect_all$n_sim       <- n_sim

    stamp   <- format(Sys.Date(), "%Y%m%d")
    rds_out <- paste0("./data/", stamp,
                    "_design_sim_", s,
                    "_nsim_", n_sim, ".rds")
    saveRDS(detect_all, rds_out)

    g <- ggplot(detect_all, aes(x = value, y = detect,
                                colour = method, group = method)) +
        geom_smooth(se = FALSE, linewidth = 0.8, span = 0.5) +
        geom_point(size = 1.5, alpha = 0.5) +
        geom_hline(yintercept = 0.8, linetype = "dashed", colour = "grey50") +
        facet_grid(design ~ condition, scales = "free") +
        scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.2)) +
        scale_colour_manual(values = c(
            "Endpoint t-test"          = "#E41A1C",
            "Change score t-test"      = "#377EB8",
            "LMM"                      = "#4DAF4A",
            "Split-body change-score"  = "#984EA3",
            "Split-body LMM"           = "#CC99FF",
            "Multi-outcome LMM"        = "#FF7F00",
            "Multi-outcome change-score" = "#FFBB78")) +
        labs(x       = NULL,
            y       = "Detectability",
            colour  = NULL,
            title   = paste0("Detectability across study design conditions",
                            " (sigma = ", round(sigma, 2), " kg)"),
            caption = "Dashed line = 0.8 threshold. Cohen's d = 0.2.") +
        theme_classic() +
        theme(legend.position  = "bottom",
            strip.background = element_blank(),
            strip.text       = element_text(face = "bold"),
            panel.spacing    = unit(1, "lines"))

    ggsave(g, filename = paste0("./figures/",
                                format(Sys.Date(), "%Y%m%d"),
                                "_design_sim_",
                                names(sigmas)[which(sigmas == sigma)],
                                "_nsim_", n_sim, ".pdf"))

}


# =============================================================================
# Bayesian equivalents of lme4 approach
# =============================================================================

# =============================================================================
# I - Bayesian equivalent of two-arm LMM
#
# This script verifies the equivalence of the Stan model by fitting both to a 
# a simulated dataset under matching estimation assumptions:
#   - lme4 is fit with REML = FALSE. Under REML, lme4 applies a 
#     degrees-of-freedom correction that inflates variance estimates relative 
#     to the likelihood mode.
# =============================================================================

# -----------------------------------------------------------------------------
# Simulate a single trial dataset
# -----------------------------------------------------------------------------
df <- sim_trial(n          = n_default,
                delta      = delta,
                times      = t_sample_default,
                a_mean     = a_mean,    a_sd    = a_sd,
                beta_mean  = beta_mean, beta_sd = beta_sd,
                sigma      = sigmas[["Within-session_CV_0.05"]],
                age_mean   = age_mean,
                type       = "systemic",
                comparison = "between")

# Two-arm design uses dominant hand only as outcome
df <- df[df$hand == "dom", ]

# -----------------------------------------------------------------------------
# lme4 fit
# -----------------------------------------------------------------------------
fit <- lmer(handgrip ~ time + time:group + (1 | id) + (0 + time | id),
            data = df, REML = FALSE)

# -----------------------------------------------------------------------------
# Bayesian fit (Stan)
# -----------------------------------------------------------------------------
data <- list(N     = nrow(df),
             N_ID  = length(unique(df$id)),
             HG    = df$handgrip,
             TIME  = df$time,
             ID    = match(df$id, unique(df$id)),
             GROUP = as.numeric(df$group != "ctl"))

model <- "./scripts/1_two_arm_LMM.stan"
post  <- stan_sample(data = data, model = model, num_chains = 4)

# -----------------------------------------------------------------------------
# Parameter-by-parameter comparison
#
# For each shared parameter the lme4 point estimate is placed alongside the
# Stan posterior mean, median, and 95% compatibility interval. Equivalence is
# judged by whether the lme4 estimate falls within the Stan 95% CI.
# -----------------------------------------------------------------------------

# Fixed effects from lme4
fixef_lme4 <- as.data.frame(coef(summary(fit)))

# Variance components from lme4. The sdcor column gives SDs, matching the
# Stan parameterisation; `grp` disambiguates the two random effects on id
# (id, id.1) and the residual.
varcor_lme4 <- as.data.frame(VarCorr(fit))
sd_lme4     <- setNames(varcor_lme4$sdcor, varcor_lme4$grp)

# Paired Stan posterior draws and lme4 point estimates, in matching order
post_draws <- list("Intercept (a_mean)"   = post$a_mean,
                   "Slope (beta_mean)"    = post$beta_mean,
                   "Treatment (treat)"    = post$treat,
                   "SD intercepts (a_sd)" = post$a_sd,
                   "SD slopes (beta_sd)"  = post$beta_sd,
                   "Residual SD (sigma)"  = post$sigma)

lme4_estimate <- c(fixef_lme4["(Intercept)",     "Estimate"],
                   fixef_lme4["time",            "Estimate"],
                   fixef_lme4["time:grouptreat", "Estimate"],
                   sd_lme4[["id"]],
                   sd_lme4[["id.1"]],
                   sd_lme4[["Residual"]])

comparison <- data.frame(
    parameter   = names(post_draws),
    lme4        = lme4_estimate,
    stan_mean   = sapply(post_draws, mean),
    stan_median = sapply(post_draws, median),
    stan_ci_lo  = sapply(post_draws, quantile, 0.025),
    stan_ci_hi  = sapply(post_draws, quantile, 0.975))

comparison$lme4_in_ci <- comparison$lme4 >= comparison$stan_ci_lo &
                        comparison$lme4 <= comparison$stan_ci_hi

# Round numeric columns for legibility (logical column preserved)
num_cols <- sapply(comparison, is.numeric)
comparison[num_cols] <- lapply(comparison[num_cols], round, 3)

print(comparison, row.names = FALSE)


# =============================================================================
# II - Bayesian equivalent of split-design
#
# This script verifies the equivalence of the Stan model by fitting both to a 
# a simulated dataset under matching estimation assumptions:
#   - lme4 is fit with REML = FALSE. Under REML, lme4 applies a 
#     degrees-of-freedom correction that inflates variance estimates relative 
#     to the likelihood mode.
# =============================================================================
# -----------------------------------------------------------------------------
# Simulate a single trial dataset
# -----------------------------------------------------------------------------
df <- sim_trial(n          = n_default,
                delta      = delta,
                times      = t_sample_default,
                a_mean     = a_mean,    a_sd    = a_sd,
                beta_mean  = beta_mean, beta_sd = beta_sd,
                sigma      = sigmas[["Within-session_CV_0.05"]],
                age_mean   = age_mean,
                type       = "local",
                comparison = "within")

df$hand <- factor(df$hand, levels = c("dom", "ndom"))

# -----------------------------------------------------------------------------
# lme4 fit
# -----------------------------------------------------------------------------
fit <- lmer(handgrip ~ time + hand + time:hand + (1 | id) + (0 + time | id) +
                       (1 | id:hand),
            data = df, REML = FALSE)

as.data.frame(coef(summary(fit)))

# Split-body LMM: tests whether slopes differ between hands across all
# timepoints. time:handndom is the treatment effect — dominant hand is
# treated, non-dominant is control, so hand and treatment are confounded
# by design.
data <- list(N     = nrow(df),
             N_ID  = length(unique(df$id)),
             HG    = df$handgrip,
             TIME  = df$time,
             ID    = match(df$id, unique(df$id)),
             HAND  = as.numeric(df$hand != "dom"))

model <- "./scripts/2_splitbody_LMM.stan"
post  <- stan_sample(data = data, model = model, num_chains = 4)

# -----------------------------------------------------------------------------
# Parameter-by-parameter comparison
#
# For each shared parameter the lme4 point estimate is placed alongside the
# Stan posterior mean, median, and 95% compatibility interval. Equivalence is
# judged by whether the lme4 estimate falls within the Stan 95% CI.
# -----------------------------------------------------------------------------

# Fixed effects from lme4
fixef_lme4 <- as.data.frame(coef(summary(fit)))

# Variance components from lme4. The sdcor column gives SDs, matching the
# Stan parameterisation; `grp` disambiguates the random effects on id
# (id, id.1), id:hand, and the residual.
varcor_lme4 <- as.data.frame(VarCorr(fit))
sd_lme4     <- setNames(varcor_lme4$sdcor, varcor_lme4$grp)

# Paired Stan posterior draws and lme4 point estimates, in matching order.
# Note: a_ndom_mean in Stan corresponds to the handndom fixed effect in lme4,
# since the per-individual ndom offset is parameterised with a non-zero prior
# mean rather than as a zero-centred random effect added to a separate fixed
# effect. Similarly a_ndom_sd corresponds to the id:hand SD in lme4.
post_draws <- list("Intercept (a_mean)"          = post$a_mean,
                   "Slope (beta_mean)"           = post$beta_mean,
                   "Hand (a_ndom_mean)"          = post$a_ndom_mean,
                   "Treatment (treat)"           = post$treat,
                   "SD intercepts (a_sd)"        = post$a_sd,
                   "SD slopes (beta_sd)"         = post$beta_sd,
                   "SD hand offset (a_ndom_sd)"  = post$a_ndom_sd,
                   "Residual SD (sigma)"         = post$sigma)

lme4_estimate <- c(fixef_lme4["(Intercept)",    "Estimate"],
                   fixef_lme4["time",           "Estimate"],
                   fixef_lme4["handndom",       "Estimate"],
                   fixef_lme4["time:handndom",  "Estimate"],
                   sd_lme4[["id.1"]],     # intercept SD
                   sd_lme4[["id"]],       # slope SD
                   sd_lme4[["id.hand"]],
                   sd_lme4[["Residual"]])

comparison <- data.frame(
    parameter   = names(post_draws),
    lme4        = lme4_estimate,
    stan_mean   = sapply(post_draws, mean),
    stan_median = sapply(post_draws, median),
    stan_ci_lo  = sapply(post_draws, quantile, 0.025),
    stan_ci_hi  = sapply(post_draws, quantile, 0.975))

comparison$lme4_in_ci <- comparison$lme4 >= comparison$stan_ci_lo &
                        comparison$lme4 <= comparison$stan_ci_hi

# Round numeric columns for legibility (logical column preserved)
num_cols <- sapply(comparison, is.numeric)
comparison[num_cols] <- lapply(comparison[num_cols], round, 3)

print(comparison, row.names = FALSE)


print(VarCorr(fit))

cat("True beta_sd (BLSA posterior mean):", beta_sd, "\n")
cat("True a_ndom_sd (lat_sd):", 2, "\n")          # default in sim_trial