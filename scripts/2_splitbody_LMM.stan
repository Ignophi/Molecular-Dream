data {
    int N;
    int N_ID;
    vector<lower=0>[N] HG;
    vector<lower=0>[N] TIME;
    array[N] int ID;
    array[N] int HAND;
}

parameters {
    real a_mean;
    real<lower=0> a_sd;

    real beta_mean;
    real<lower=0> beta_sd;

    real a_ndom_mean;
    real<lower=0> a_ndom_sd;

    real treat;

    vector[N_ID] a;
    vector[N_ID] a_ndom;
    vector[N_ID] beta;
    real<lower=0> sigma;
}

model {
    // Baseline handgrip strength come from same distribution
    target += normal_lpdf(a | a_mean, a_sd);
    // Difference between dom and non-dom hands come from same distribution
    target += normal_lpdf(a_ndom | a_ndom_mean, a_ndom_sd);
    // Deterioration with age comes from same distribution
    target += normal_lpdf(beta | beta_mean, beta_sd);
    // Prior is no treatment effect
    //target += normal_lpdf(treat | 0, 1);

    for (n in 1:N) {
        target += normal_lpdf(HG[n] | (a[ID[n]] + a_ndom[ID[n]] * HAND[n])  + TIME[n]*(beta[ID[n]] + treat * HAND[n]), sigma);
    }
}