library("ggplot2")
library("cowplot")
library("viridis")

## ---------------------------------------------------------------------------
## Figure 1. The time scale of an intervention effect
##
## rho = magnitude of the effect of G_I on x, relative to that of G_0.
##       Curves darken and thicken as rho grows.
##
## Row 1  G_I is distinct from G_0
##        (A) rho > 1  : reversal, at a rate set by rho, not by G_0
##        (B) rho <= 1 : G_0 is offset at most completely; halt or slowing
## Row 2  G_I modifies the parameters of G_0 (no restorative process exists,
##        so rho <= 1 by construction)
##        (C) I_h, the best case: new deterioration halted
##        (D) I_s: new deterioration slowed, bounded by the halt ceiling
## ---------------------------------------------------------------------------

r0      <- 1.0     # rate of deterioration in x under G_0 (units / year)
x_start <- 100     # x before deterioration begins
t_hist  <- 20      # years of deterioration accumulated before the intervention
t_max   <- 10      # years followed after the intervention
x0      <- x_start - r0 * t_hist          # x when the intervention starts

## one visual system: the untreated arm here plays the role of placebo there.
pal <- list(untreated = "#C1663B",   # placebo / untreated
            treated   = "#1F6F78",   # active treatment / under G_I
            halt      = "black",     # the halt: reference line in every panel
            window    = "grey94")

t_pre  <- seq(-t_hist, 0, length.out = 200)
t_post <- seq(0, t_max, length.out = 600)

## rho is encoded identically in every panel, so that a given width and shade
## denote the same magnitude wherever they appear. The mapping is on log(rho),
## since rho spans 0.25-15 and a linear map would leave the rho <= 1 curves
## indistinguishable from one another.

rho_lim  <- c(0.25, 15)     # full range of rho shown anywhere in the figure
lw_range <- c(0.35, 1.45)
al_range <- c(0.50, 1.00)

## Line pattern is ordinal in rho as well: dashes lengthen and finally close up
## into a solid line as rho grows, so the ordering survives greyscale printing
## and remains readable where curves run close together. One pattern per rho
## used anywhere in the figure; edit both vectors together.
rho_levels <- c(0.25, 0.5, 0.75, 1, 1.5, 3, 6, 15)
lt_ladder  <- c("11", "22", "42", "62", "82", "c2", "f2", "solid")

enc <- function(rho) {
  u <- (log(rho) - log(rho_lim[1])) / diff(log(rho_lim))
  i <- match(rho, rho_levels)                       # nearest level if unlisted
  i[is.na(i)] <- vapply(rho[is.na(i)],
                        function(r) which.min(abs(log(rho_levels) - log(r))),
                        integer(1))
  list(w  = lw_range[1] + u * diff(lw_range),
       a  = al_range[1] + u * diff(al_range),
       lt = lt_ladder[i])
}

untreated <- function(t) x0 - r0 * t

## G_I distinct: it acts on x at rate rho * r0 against G_0's r0, so the net
## rate is (rho - 1) * r0. Restoration stops once the deficit is recovered.
traj_distinct <- function(t, rho) pmin(x_start, x0 + (rho - 1) * r0 * t)

## G_I modifies G_0: a fraction rho of new deterioration is prevented. What has
## already accumulated is not corrected, so x0 is an upper bound.
traj_modify <- function(t, rho) x0 - (1 - rho) * r0 * t

panel <- function(rhos = NULL, fun = traj_modify, title, subtitle,
                  show_y = FALSE, label_levels = NULL) {

  rhos  <- sort(rhos); n <- length(rhos)
  if (n > 0) {
    e <- enc(rhos); alpha <- e$a; lw <- e$w; lty <- e$lt
  } else {
    alpha <- lw <- lty <- numeric(0)      # panel carries the reference only
  }

  curves <- do.call(rbind, lapply(seq_len(n), function(i) {
    data.frame(t = t_post, x = fun(t_post, rhos[i]),
               rho = rhos[i], a = alpha[i], w = lw[i], lt = lty[i])
  }))

  ## label each curve where it is separated from its neighbours: on the rising
  ## segment at a height reserved for that curve, otherwise at the right end
  lab <- do.call(rbind, lapply(seq_len(n), function(i) {
    rho <- rhos[i]; tl <- t_max; yl <- fun(t_max, rho)
    if (!is.null(label_levels) && rho > 1) {
      y_try <- label_levels[i]
      t_try <- (y_try - x0) / ((rho - 1) * r0)
      if (t_try <= t_max) { tl <- t_try; yl <- y_try }
    }
    steep <- !is.null(label_levels) && rho > 1 && tl < t_max
    data.frame(t = tl + if (steep) 0.85 else 0.30,
               x = yl + if (steep) -2.4 else 0.60,
               lab = paste0("rho == ", format(rho, drop0trailing = TRUE)),
               a = max(alpha[i], 0.70))
  }))

  p <- ggplot() +
    annotate("rect", xmin = 0, xmax = t_max, ymin = -Inf, ymax = Inf,
             fill = pal$window) +
    geom_line(data = data.frame(t = t_pre, x = x_start - r0 * (t_pre + t_hist)),
              aes(t, x), colour = pal$untreated, linewidth = 0.55)

  ## The halt (rho = 1) is drawn in every panel, in black and at one fixed
  ## weight, as a common reference: it is the ceiling on what an intervention
  ## that only modifies G_0 can achieve, and the boundary of the reversal
  ## regime for one that is distinct from it.
  p <- p +
    geom_line(data = data.frame(t = t_post, x = rep(x0, length(t_post))),
              aes(t, x), colour = pal$halt, linewidth = enc(1)$w,
              linetype = enc(1)$lt) +
    annotate("text", x = t_max + 0.30, y = x0 + 0.6, label = "I[h]",
             parse = TRUE, hjust = 0, size = 2.5, colour = pal$halt) +
    geom_line(data = data.frame(t = t_post, x = untreated(t_post)),
              aes(t, x), colour = pal$untreated, linewidth = 0.55) +
    annotate("text", x = t_max + 0.35, y = untreated(t_max), label = "untreated",
             hjust = 0, size = 2.4, colour = pal$untreated)

  if (n > 0)
    p <- p +
      geom_line(data = curves, aes(t, x, group = rho, linetype = lt),
                colour = pal$treated, alpha = curves$a, linewidth = curves$w) +
      geom_text(data = lab, aes(t, x, label = lab), parse = TRUE,
                hjust = 0, size = 2.5, colour = pal$treated, alpha = lab$a)

  p +
    scale_linetype_identity() +
    geom_vline(xintercept = 0, colour = "grey55", linewidth = 0.25,
               linetype = "22") +
    annotate("text", x = 0.45, y = 102.2, label = "italic(I)", parse = TRUE,
             hjust = 0, size = 3, colour = "grey35") +
    scale_x_continuous(breaks = c(-20, -10, 0, 10), limits = c(-t_hist, 14.5),
                       expand = expansion(mult = c(0.02, 0))) +
    scale_y_continuous(limits = c(67, 104)) +
    labs(x = "Years",
         y = if (show_y) expression(paste("Functional measure  ", x[p])) else NULL,
         title = title, subtitle = subtitle) +
    theme_cowplot(font_size = 9) +
    theme(plot.title    = element_text(size = 8.5, face = "plain"),
          plot.subtitle = element_text(size = 8, colour = "grey30",
                                       margin = margin(b = 4)),
          axis.title    = element_text(size = 8),
          plot.margin   = margin(4, 4, 2, 2))
}

pA <- panel(c(1.5, 3, 6, 15), traj_distinct, show_y = TRUE,
            label_levels = c(88, 91, 94, 97),
            title    = expression(paste("effect on ", x[p], " exceeds that of ",
                                        G[0], "   (", rho > 1, ")")),
            subtitle = expression(paste("reversal, at a rate set by ", rho,
                                        ", not by ", G[0])))

pB <- panel(c(0.25, 0.5, 0.75), traj_distinct,
            title    = expression(paste("effect on ", x[p],
                                        " does not exceed that of ", G[0],
                                        "   (", rho <= 1, ")")),
            subtitle = expression(paste("G"[0], " offset at most completely: halt or slowing")))

pC <- panel(NULL, traj_modify, show_y = TRUE,
            title    = expression(paste("best case: new deterioration halted   (",
                                        I[h], ")")),
            subtitle = expression(paste("separation widens only as ", G[0],
                                        " continues untreated")))

pD <- panel(c(0.25, 0.5, 0.75), traj_modify,
            title    = expression(paste("new deterioration slowed   (", I[s], ")")),
            subtitle = expression(paste("bounded above by the halt reference, ", I[h])))

strip <- function(txt) ggdraw() + draw_label(txt, angle = -90, size = 8.5,
                                             colour = "grey20")

row1 <- plot_grid(pA, pB, strip(expression(paste(G[I], " distinct from ", G[0]))),
                  nrow = 1, rel_widths = c(1.07, 1, 0.06),
                  labels = c("A", "B", ""), label_size = 11,
                  label_x = 0.005, hjust = 0, vjust = 1.05)

row2 <- plot_grid(pC, pD, strip(expression(paste(G[I], " modifies ", G[0]))),
                  nrow = 1, rel_widths = c(1.07, 1, 0.06),
                  labels = c("C", "D", ""), label_size = 11,
                  label_x = 0.005, hjust = 0, vjust = 1.05)

fig <- plot_grid(row1, row2, ncol = 1)

ggsave("./figures/plots/fig_A1_timescales.pdf", fig,
       width = 8.6, height = 5.3, units = "in", device = cairo_pdf)
ggsave("./figures/plots/fig_A1_timescales.png", fig,
       width = 8.6, height = 5.3, units = "in", dpi = 300)

## ---------------------------------------------------------------------------
## Figure 2. Amyloid-PET clearance across two phase 3 trials
##   left  panel : donanemab   (TRAILBLAZER-ALZ 2, Sims et al. 2023, JAMA)
##   right panel : lecanemab   (Clarity AD, van Dyck et al. 2023, NEJM)
## ---------------------------------------------------------------------------

d <- read.csv("data/amyloid_pet_digitized.csv", stringsAsFactors = FALSE)


## Left = donanemab, right = lecanemab: set the factor levels in that order.

d$panel <- factor(
  ifelse(d$study == "TRAILBLAZER-ALZ 2",
         "Donanemab clinical trial",
         "Lecanemab clinical trial"),
  levels = c("Donanemab clinical trial", "Lecanemab clinical trial")
)


## colour = active drug vs placebo; shape / linetype = cohort within the trial

d$arm_type <- factor(ifelse(d$arm == "Placebo", "Placebo", "Active treatment"),
                     levels = c("Active treatment", "Placebo"))

d$cohort <- NA_character_
d$cohort[d$population == "All participants (PET substudy)"] <- "All participants"
d$cohort[d$population == "Low/medium tau"]                  <- "Low/medium tau"
d$cohort[grepl("Combined", d$population, fixed = TRUE)]     <- "Combined tau"
d$cohort <- factor(d$cohort,
                   levels = c("All participants", "Low/medium tau", "Combined tau"))

d$series <- interaction(d$panel, d$arm_type, d$cohort, drop = TRUE)


## The two source figures do NOT show the same thing: NEJM Fig 2B plots
## standard errors, JAMA Fig 3A plots 95% CIs. Approximating the NEJM bars as
## mean +/- 1.96*SE puts both panels on the same footing. Set to FALSE to keep
## the intervals exactly as published (then say so in the caption).

harmonise_ci <- TRUE

if (harmonise_ci) {
  i  <- which(d$err_type == "SE" & !is.na(d$err_lower))
  se <- (d$err_upper[i] - d$err_lower[i]) / 2
  d$err_lower[i] <- d$amyloid_change_centiloids[i] - 1.96 * se
  d$err_upper[i] <- d$amyloid_change_centiloids[i] + 1.96 * se
  d$err_type[i]  <- "95% CI (approx. from SE)"
}

## baseline rows have no interval; collapse the band to the point so the
## ribbon starts at t = 0 instead of being dropped
nb <- is.na(d$err_lower)
d$err_lower[nb] <- d$amyloid_change_centiloids[nb]
d$err_upper[nb] <- d$amyloid_change_centiloids[nb]


pal <- c("Active treatment" = "#1F6F78", "Placebo" = "#C1663B")

p <- ggplot(d, aes(x = time_months, y = amyloid_change_centiloids,
                   group = series)) +
  geom_hline(yintercept = 0, colour = "grey70", linewidth = 0.3) +
  geom_ribbon(aes(ymin = err_lower, ymax = err_upper, fill = arm_type),
              alpha = 0.16, colour = NA) +
  geom_line(aes(colour = arm_type, linetype = cohort), linewidth = 0.7) +
  geom_point(aes(colour = arm_type, shape = cohort),
             size = 2.1, fill = "white", stroke = 0.7) +

  facet_wrap(~ panel, nrow = 1) +

  scale_colour_manual(values = pal, name = NULL) +
  scale_fill_manual(values = pal, guide = "none") +
  scale_shape_manual(values = c("All participants" = 21,
                                "Low/medium tau"   = 24,
                                "Combined tau"     = 22),
                     name = NULL, drop = TRUE) +
  scale_linetype_manual(values = c("All participants" = "solid",
                                   "Low/medium tau"   = "solid",
                                   "Combined tau"     = "22"),
                        name = NULL, drop = TRUE) +

  scale_x_continuous(breaks = seq(0, 18, 3), limits = c(0, 18.3),
                     expand = expansion(mult = c(0.02, 0.04))) +
  scale_y_continuous(breaks = seq(-100, 0, 20),
                     labels = function(x) ifelse(x < 0, paste0("\u2212", abs(x)), x),
                     expand = expansion(mult = c(0.06, 0.08))) +

  labs(
    x = "Months since baseline",
    y = "Amyloid PET change from baseline (Centiloids)"
  ) +

  guides(
    colour   = guide_legend(order = 1, override.aes = list(shape = NA, linetype = "solid")),
    shape    = guide_legend(order = 2, override.aes = list(colour = "grey25")),
    linetype = guide_legend(order = 2)
  ) +

  theme_minimal(base_size = 10) +
  theme(
    strip.text        = element_text(face = "bold", size = 10, hjust = 0,
                                     margin = margin(t = 4, b = 5, l = 2)),
    strip.background  = element_rect(fill = "grey93", colour = NA),
    panel.grid.minor  = element_blank(),
    panel.grid.major.x = element_blank(),
    panel.grid.major.y = element_line(colour = "grey90", linewidth = 0.35),
    panel.spacing     = unit(14, "pt"),
    axis.line.x       = element_line(colour = "grey30", linewidth = 0.35),
    axis.ticks.x      = element_line(colour = "grey30", linewidth = 0.35),
    axis.ticks.length = unit(2.5, "pt"),
    axis.text         = element_text(colour = "grey20"),
    axis.title.x      = element_text(margin = margin(t = 7)),
    axis.title.y      = element_text(margin = margin(r = 7)),
    legend.position   = "bottom",
    legend.box        = "horizontal",
    legend.key.width  = unit(22, "pt"),
    legend.margin     = margin(t = 2),
    plot.margin       = margin(10, 12, 8, 8)
  )

if (interactive()) print(p)

ggsave("./figures/plots/amyloid_pet_faceted.png", p, width = 8.2, height = 4.4, dpi = 300)
ggsave("./figures/plots/amyloid_pet_faceted.pdf", p, width = 8.2, height = 4.4, device = cairo_pdf)

## ---------------------------------------------------------------------------
## Figure 3. Detectability across study designs, by sample size, number of
## measurements and follow-up duration
## ---------------------------------------------------------------------------
rds_files <- c(
    "./data/design_sim_Within-session_CV_0.05_nsim_1000.rds",
    "./data/design_sim_BLSA_residual_0.1_nsim_1000.rds"
)

condition_labels <- c(
    "Sample size" = "Sample size (n)",
    "Number of timepoints" = "Number of measurements",
    "Follow-up duration" = "Follow-up duration (years)"
)

design_labels <- c(
    "Two-arm" = "Two-arm",
    "Split-body" = "Split-body",
    "Multi-outcome" = "Multi-outcome"
)

method_colours <- c(
    # Two-arm
    "Endpoint t-test"                   = "#E41A1C",
    "Change-score t-test"               = "#377EB8",
    "LMM"                               = "#4DAF4A",
    # Split-body
    "Paired change-score t-test"        = "#984EA3",
    "Split-body LMM"                    = "#CC99FF",
    # Multi-outcome
    "Multi-outcome change-score t-test" = "#FFBB78",
    "Multi-outcome LMM"                 = "#FF7F00"
)

relabel_methods <- function(detect_all) {

    detect_all$method <- as.character(detect_all$method)

    detect_all$method[detect_all$method == "Change score t-test"] <-
        "Change-score t-test"

    detect_all$method[detect_all$method == "Split-body change-score"] <-
        "Paired change-score t-test"

    detect_all$method[detect_all$method == "Multi-outcome change-score"] <-
        "Multi-outcome change-score t-test"

    # Fix the legend order instead of leaving it alphabetical
    detect_all$method <- factor(
        detect_all$method,
        levels = names(method_colours)
    )

    detect_all
}

make_plot <- function(detect_all) {

    ggplot(
        detect_all,
        aes(
            x = value,
            y = detect,
            colour = method,
            group = method
        )
    ) +

        geom_smooth(
            se = FALSE,
            linewidth = 0.8,
            span = 0.5
        ) +

        geom_point(
            size = 1.5,
            alpha = 0.5
        ) +

        geom_hline(
            yintercept = 0.8,
            linetype = "dashed",
            colour = "grey50"
        ) +

        facet_grid(
            design ~ condition,
            scales = "free",
            axes = "all_x",
            axis.labels = "all_x",
            labeller = labeller(
                design = design_labels,
                condition = condition_labels
            )
        ) +

        scale_colour_manual(
            name = "Method",
            values = method_colours
        ) +

        scale_y_continuous(
            limits = c(0, 1),
            breaks = seq(0, 1, 0.2)
        ) +

        labs(
            x = NULL,
            y = "Detectability",
            caption = "Dashed line = 0.8 threshold. Cohen's d = 0.2."
        ) +

        theme_classic() +

        theme(
            strip.background = element_blank(),
            strip.text = element_text(face = "bold"),
            panel.spacing = unit(1, "lines"),

            panel.grid.major.y = element_line(
                colour = "grey85",
                linewidth = 0.4
            ),
            panel.grid.minor.y = element_blank()
        )
}

for (rds_file in rds_files) {

    message("Plotting: ", rds_file)

    detect_all <- readRDS(rds_file)
    detect_all <- relabel_methods(detect_all)

    g <- make_plot(detect_all)

    out_file <- file.path(
        "./figures/plots/",
        paste0(tools::file_path_sans_ext(basename(rds_file)), ".pdf")
    )

    ggsave(
        g,
        filename = out_file,
        width = 12,
        height = 8
    )
}

## ---------------------------------------------------------------------------
## Figure 4. The three requirements for surrogate validity (R1, R2, R3)
##
## Top row    : causal diagram under G_I for each scenario
## Bottom row : what the investigator observes, from data simulated under that
##              same diagram. Three quantities, all in SD units of the relevant
##              variable:
##                (i)   the intervention effect on the surrogate, delta x_m
##                (ii)  the effect on x_p *implied* by x_m, obtained by
##                      calibrating x_p on x_m in the control arm and applying
##                      that mapping to the observed change in x_m
##                (iii) the effect on x_p actually observed
##              The surrogate is doing its job only when (ii) and (iii) agree.
## ---------------------------------------------------------------------------

set.seed(2026)

pal <- list(
  I        = "#3B3B3B",                 # intervention node
  xm       = viridis(5, option = "D")[3],   # surrogate / molecular variable
  xp       = viridis(5, option = "D")[1],   # primary variable
  other    = "grey75",                  # U, x_k and other background nodes
  edge     = "grey25",
  absent   = "#B2182B",                 # an arrow the scenario denies
  surrogate_based = viridis(5, option = "D")[3],
  primary  = viridis(5, option = "D")[1]
)

node_r  <- 0.21    # node radius, data units (for trimming arrow ends)
node_sz <- 11      # node radius, points (drawing)

theme_dag <- function() {
  theme_void() +
    theme(plot.title = element_text(size = 8.5, hjust = 0.5,
                                    margin = margin(t = 2, b = 0)),
          plot.margin = margin(10, 2, 0, 2))
}

## ---- helpers for drawing diagrams -----------------------------------------

## node positions shared by all panels, so the eye can compare across them
P <- data.frame(
  name = c("I", "xm", "xp", "xk", "U"),
  x    = c(0.00, 1.10, 2.20, 1.10, 1.75),
  y    = c(0.00, 0.75, 0.00, -0.75, 1.15),
  lab  = c("I", "x[m]", "x[p]", "x[k]", "U"),
  stringsAsFactors = FALSE
)
pos <- function(n) P[P$name == n, ]

## straight arrow between two nodes, trimmed so it stops at the node edge
edge_seg <- function(from, to, r = node_r) {
  a <- pos(from); b <- pos(to)
  dx <- b$x - a$x; dy <- b$y - a$y; L <- sqrt(dx^2 + dy^2)
  data.frame(x    = a$x + dx / L * r, y    = a$y + dy / L * r,
             xend = b$x - dx / L * r, yend = b$y - dy / L * r)
}

arrow_style <- arrow(length = unit(0.055, "in"), type = "closed")

draw_edge <- function(from, to, colour = pal$edge, linetype = "solid",
                      linewidth = 0.45) {
  geom_segment(data = edge_seg(from, to),
               aes(x = x, y = y, xend = xend, yend = yend),
               colour = colour, linetype = linetype, linewidth = linewidth,
               arrow = arrow_style)
}

## an arrow the scenario explicitly denies: dotted, with a cross through it
draw_absent_edge <- function(from, to, colour = pal$absent) {
  e  <- edge_seg(from, to)
  mx <- (e$x + e$xend) / 2; my <- (e$y + e$yend) / 2
  d  <- 0.085
  cross <- data.frame(x    = c(mx - d, mx - d),
                      y    = c(my - d, my + d),
                      xend = c(mx + d, mx + d),
                      yend = c(my + d, my - d))
  list(
    geom_segment(data = e, aes(x = x, y = y, xend = xend, yend = yend),
                 colour = colour, linetype = "dotted", linewidth = 0.4,
                 arrow = arrow_style),
    geom_segment(data = cross, aes(x = x, y = y, xend = xend, yend = yend),
                 colour = colour, linewidth = 0.55)
  )
}

## curved arrow, used for the unmediated I -> x_p path in the R3 panel
draw_curved_edge <- function(from, to, curvature = 0.45, colour = pal$edge,
                             linetype = "solid") {
  e <- edge_seg(from, to, r = node_r * 1.05)
  geom_curve(data = e, aes(x = x, y = y, xend = xend, yend = yend),
             curvature = curvature, colour = colour, linetype = linetype,
             linewidth = 0.45, arrow = arrow_style)
}

draw_nodes <- function(names) {
  d <- P[P$name %in% names, ]
  fills <- c(I = pal$I, xm = pal$xm, xp = pal$xp, xk = pal$other, U = pal$other)
  d$fill <- fills[d$name]
  list(
    geom_point(data = d, aes(x = x, y = y), shape = 21, size = node_sz,
               fill = d$fill, colour = "white", stroke = 0.7),
    geom_text(data = d, aes(x = x, y = y, label = lab), parse = TRUE,
              colour = "white", size = 3.1)
  )
}

dag_canvas <- function(title, layers) {
  ggplot() + layers +
    coord_fixed(xlim = c(-0.40, 2.60), ylim = c(-1.15, 1.50)) +
    ggtitle(title) + theme_dag()
}

## ---- the four scenarios ----------------------------------------------------
## Each entry supplies (a) the diagram layers and (b) a data-generating
## function consistent with that diagram. Keeping them side by side is the
## point: the bottom row is what the top row implies, not a separate claim.

scenarios <- list(

  valid = list(
    title  = expression(paste("R1-R3 hold")),
    verdict = "surrogate and primary agree",
    layers = list(draw_edge("I", "xm"), draw_edge("xm", "xp"),
                  draw_nodes(c("I", "xm", "xp"))),
    gen = function(n) {
      Tr <- rep(0:1, each = n)
      xm <- 1.00 * Tr + rnorm(2 * n)
      xp <- 0.70 * xm + rnorm(2 * n)
      data.frame(Tr, xm, xp)
    }),

  r1 = list(
    title  = expression(paste("R1 fails: ", I, " does not change ", x[m])),
    verdict = "effect missed (false negative)",
    layers = list(draw_absent_edge("I", "xm"),
                  draw_edge("I", "xk"), draw_edge("xk", "xp"),
                  draw_edge("xm", "xp"),
                  draw_nodes(c("I", "xm", "xp", "xk"))),
    gen = function(n) {
      Tr <- rep(0:1, each = n)
      xk <- 1.00 * Tr + rnorm(2 * n)      # the route the intervention takes
      xm <- rnorm(2 * n)                  # a genuine cause of x_p, but untouched
      xp <- 0.70 * xk + 0.50 * xm + rnorm(2 * n)
      data.frame(Tr, xm, xp)
    }),

  r2 = list(
    title  = expression(paste("R2 fails: ", x[m], " does not cause ", x[p])),
    verdict = "effect asserted (false positive)",
    layers = list(draw_edge("I", "xm"),
                  draw_absent_edge("xm", "xp"),
                  draw_edge("U", "xm"), draw_edge("U", "xp"),
                  draw_nodes(c("I", "xm", "xp", "U"))),
    gen = function(n) {
      Tr <- rep(0:1, each = n)
      U  <- rnorm(2 * n)                  # shared upstream cause
      xm <- 1.00 * Tr + 0.90 * U + rnorm(2 * n, sd = 0.6)
      xp <-             0.90 * U + rnorm(2 * n, sd = 0.6)
      data.frame(Tr, xm, xp)
    }),

  r3 = list(
    title  = expression(paste("R3 fails: ", x[m], " mediates only part")),
    verdict = "effect underestimated",
    layers = list(draw_edge("I", "xm"), draw_edge("xm", "xp"),
                  draw_curved_edge("I", "xp", curvature = 0.42),
                  draw_nodes(c("I", "xm", "xp"))),
    gen = function(n) {
      Tr <- rep(0:1, each = n)
      xm <- 1.00 * Tr + rnorm(2 * n)
      xp <- 0.35 * xm + 0.50 * Tr + rnorm(2 * n)   # residual unmediated path
      data.frame(Tr, xm, xp)
    })
)

n_per_arm <- 300
n_boot    <- 2000

## All three quantities in SD units of the variable concerned, so that the
## surrogate-based inference and the direct observation sit on one axis.
observed_quantities <- function(d) {
  ctrl <- d$Tr == 0; trt <- d$Tr == 1
  s_m <- sd(d$xm[ctrl]); s_p <- sd(d$xp[ctrl])
  dm  <- (mean(d$xm[trt]) - mean(d$xm[ctrl])) / s_m
  dp  <- (mean(d$xp[trt]) - mean(d$xp[ctrl])) / s_p
  ## calibration of x_p on x_m, estimated where the intervention is absent
  b_std <- unname(coef(lm(xp ~ xm, data = d[ctrl, ]))[2]) * s_m / s_p
  c(delta_m = dm, implied = b_std * dm, observed = dp)
}

boot_ci <- function(d, B = n_boot) {
  i0 <- which(d$Tr == 0); i1 <- which(d$Tr == 1)
  out <- replicate(B, observed_quantities(
    d[c(sample(i0, replace = TRUE), sample(i1, replace = TRUE)), ]))
  t(apply(out, 1, quantile, probs = c(0.025, 0.975)))
}

quantity_levels <- c("observed", "implied", "delta_m")   # bottom to top
quantity_labels <- c(
  expression(paste("effect on ", x[p], ", observed")),
  expression(paste("effect on ", x[p], ", implied by ", x[m])),
  expression(paste("effect on ", x[m])))

estimates_panel <- function(sc, show_y = FALSE) {
  d   <- sc$gen(n_per_arm)
  est <- observed_quantities(d)
  ci  <- boot_ci(d)
  df  <- data.frame(quantity = factor(names(est), levels = quantity_levels),
                    est = as.numeric(est), lo = ci[, 1], hi = ci[, 2])
  df$source <- ifelse(df$quantity == "observed", "primary", "surrogate-based")

  ggplot(df, aes(x = est, y = quantity, colour = source)) +
    geom_vline(xintercept = 0, linetype = "dashed",
               colour = "grey60", linewidth = 0.3) +
    geom_errorbarh(aes(xmin = lo, xmax = hi), height = 0, linewidth = 0.5) +
    geom_point(size = 2) +
    scale_colour_manual(values = c("surrogate-based" = pal$surrogate_based,
                                   "primary" = pal$primary), name = NULL) +
    scale_y_discrete(labels = if (show_y) quantity_labels else NULL) +
    scale_x_continuous(limits = c(-0.35, 1.45),
                       breaks = seq(0, 1.2, by = 0.4)) +
    labs(x = "Intervention effect (SD units)", y = NULL,
         subtitle = sc$verdict) +
    theme_cowplot(font_size = 9) +
    theme(plot.subtitle = element_text(size = 8, colour = "grey30",
                                       margin = margin(b = 4)),
          axis.text.y  = element_text(size = 7.5),
          axis.title.x = element_text(size = 8),
          axis.line.y  = element_blank(),
          axis.ticks.y = element_blank(),
          legend.position = "none",
          plot.margin = margin(4, 6, 2, 2))
}

dag_row <- lapply(scenarios, function(sc) dag_canvas(sc$title, sc$layers))
est_row <- Map(function(sc, first) estimates_panel(sc, show_y = first),
               scenarios, c(TRUE, FALSE, FALSE, FALSE))

legend_plot <- estimates_panel(scenarios$valid, show_y = TRUE) +
  theme(legend.position = "bottom", legend.text = element_text(size = 8),
        legend.justification = "center",
        legend.key.width = unit(0.35, "cm"))
shared_legend <- get_legend(legend_plot)

col_w <- c(1.42, 1, 1, 1)

body <- plot_grid(
  plot_grid(plotlist = dag_row, nrow = 1, rel_widths = col_w,
            labels = c("A", "B", "C", "D"), label_size = 11,
            label_x = 0.01, hjust = 0, vjust = 1.1),
  plot_grid(plotlist = est_row, nrow = 1, rel_widths = col_w),
  ncol = 1, rel_heights = c(1, 1.02))

fig <- plot_grid(body, shared_legend, ncol = 1, rel_heights = c(1, 0.06))

ggsave("figures/plots/fig_surrogacy_requirements.pdf", fig,
       width = 11.5, height = 5.4, units = "in", device = cairo_pdf)
ggsave("figures/plots/fig_surrogacy_requirements.png", fig,
       width = 11.5, height = 5.4, units = "in", dpi = 300)