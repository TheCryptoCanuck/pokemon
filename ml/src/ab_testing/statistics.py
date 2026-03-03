"""Statistical significance testing for A/B experiments.

Provides hypothesis testing and confidence interval computation
to determine if model version differences are statistically
significant.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

import numpy as np
from scipy import stats

logger = logging.getLogger(__name__)


@dataclass
class SignificanceResult:
    """Result of a statistical significance test."""

    test_name: str
    statistic: float
    p_value: float
    is_significant: bool
    confidence_level: float
    effect_size: float
    interpretation: str


def proportion_z_test(
    successes_a: int,
    total_a: int,
    successes_b: int,
    total_b: int,
    confidence_level: float = 0.95,
) -> SignificanceResult:
    """Two-proportion z-test for comparing success rates.

    Tests whether the difference in accuracy/success rates between
    two model variants is statistically significant.

    Args:
        successes_a: Number of successes in variant A.
        total_a: Total samples in variant A.
        successes_b: Number of successes in variant B.
        total_b: Total samples in variant B.
        confidence_level: Statistical confidence level (default 0.95).

    Returns:
        SignificanceResult with test details.
    """
    if total_a == 0 or total_b == 0:
        return SignificanceResult(
            test_name="proportion_z_test",
            statistic=0.0,
            p_value=1.0,
            is_significant=False,
            confidence_level=confidence_level,
            effect_size=0.0,
            interpretation="Insufficient data for significance testing",
        )

    p_a = successes_a / total_a
    p_b = successes_b / total_b

    # Pooled proportion
    p_pool = (successes_a + successes_b) / (total_a + total_b)
    se = np.sqrt(p_pool * (1 - p_pool) * (1 / total_a + 1 / total_b))

    if se == 0:
        z_stat = 0.0
        p_value = 1.0
    else:
        z_stat = (p_a - p_b) / se
        p_value = 2 * (1 - stats.norm.cdf(abs(z_stat)))

    alpha = 1 - confidence_level
    is_significant = p_value < alpha
    effect_size = abs(p_a - p_b)

    winner = "A" if p_a > p_b else "B" if p_b > p_a else "neither"

    if is_significant:
        interpretation = (
            f"Variant {winner} is significantly better "
            f"(p={p_value:.4f}, effect={effect_size:.4f})"
        )
    else:
        interpretation = (
            f"No significant difference detected "
            f"(p={p_value:.4f}, effect={effect_size:.4f})"
        )

    return SignificanceResult(
        test_name="proportion_z_test",
        statistic=z_stat,
        p_value=p_value,
        is_significant=is_significant,
        confidence_level=confidence_level,
        effect_size=effect_size,
        interpretation=interpretation,
    )


def welch_t_test(
    values_a: list[float],
    values_b: list[float],
    confidence_level: float = 0.95,
) -> SignificanceResult:
    """Welch's t-test for comparing means of two groups.

    Tests whether the mean confidence score or latency differs
    significantly between two model variants.

    Args:
        values_a: Metric values from variant A.
        values_b: Metric values from variant B.
        confidence_level: Statistical confidence level.

    Returns:
        SignificanceResult with test details.
    """
    if len(values_a) < 2 or len(values_b) < 2:
        return SignificanceResult(
            test_name="welch_t_test",
            statistic=0.0,
            p_value=1.0,
            is_significant=False,
            confidence_level=confidence_level,
            effect_size=0.0,
            interpretation="Insufficient data for significance testing",
        )

    t_stat, p_value = stats.ttest_ind(values_a, values_b, equal_var=False)

    alpha = 1 - confidence_level
    is_significant = p_value < alpha

    mean_a = np.mean(values_a)
    mean_b = np.mean(values_b)
    pooled_std = np.sqrt(
        (np.std(values_a, ddof=1) ** 2 + np.std(values_b, ddof=1) ** 2) / 2
    )
    effect_size = abs(mean_a - mean_b) / pooled_std if pooled_std > 0 else 0.0

    if is_significant:
        better = "A" if mean_a > mean_b else "B"
        interpretation = (
            f"Variant {better} has significantly higher mean "
            f"(A={mean_a:.4f}, B={mean_b:.4f}, Cohen's d={effect_size:.3f})"
        )
    else:
        interpretation = (
            f"No significant difference in means "
            f"(A={mean_a:.4f}, B={mean_b:.4f}, p={p_value:.4f})"
        )

    return SignificanceResult(
        test_name="welch_t_test",
        statistic=t_stat,
        p_value=p_value,
        is_significant=is_significant,
        confidence_level=confidence_level,
        effect_size=effect_size,
        interpretation=interpretation,
    )


def compute_sample_size(
    baseline_rate: float,
    minimum_detectable_effect: float,
    confidence_level: float = 0.95,
    power: float = 0.80,
) -> int:
    """Compute minimum sample size per variant for a proportions test.

    Use this before starting an experiment to determine how long
    to run it for meaningful results.

    Args:
        baseline_rate: Expected success rate for the control variant.
        minimum_detectable_effect: Smallest improvement worth detecting.
        confidence_level: Statistical confidence level.
        power: Statistical power (1 - Type II error rate).

    Returns:
        Required sample size per variant.
    """
    alpha = 1 - confidence_level
    z_alpha = stats.norm.ppf(1 - alpha / 2)
    z_beta = stats.norm.ppf(power)

    p1 = baseline_rate
    p2 = baseline_rate + minimum_detectable_effect

    numerator = (z_alpha * np.sqrt(2 * p1 * (1 - p1)) + z_beta * np.sqrt(
        p1 * (1 - p1) + p2 * (1 - p2)
    )) ** 2
    denominator = (p2 - p1) ** 2

    return int(np.ceil(numerator / denominator))
