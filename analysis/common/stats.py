"""Mean and 95% confidence interval (Student t) of a list of samples."""
import math

# Two-sided 95% t quantiles by degrees of freedom; above 30, the normal 1.96.
_T95 = [None, 12.706, 4.303, 3.182, 2.776, 2.571, 2.447, 2.365, 2.306, 2.262, 2.228,
        2.201, 2.179, 2.160, 2.145, 2.131, 2.120, 2.110, 2.101, 2.093, 2.086,
        2.080, 2.074, 2.069, 2.064, 2.060, 2.056, 2.052, 2.048, 2.045, 2.042]


def mean_ci95(xs):
    """(mean, half-width of the 95% CI); half-width is None for one sample."""
    n = len(xs)
    m = sum(xs) / n
    if n < 2:
        return m, None
    sd = math.sqrt(sum((x - m) ** 2 for x in xs) / (n - 1))
    t = _T95[n - 1] if n - 1 < len(_T95) else 1.96
    return m, t * sd / math.sqrt(n)
