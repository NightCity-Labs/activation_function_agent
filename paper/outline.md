# Learning Activation Functions via Correlation Objectives

## Paper Structure

### Abstract
- Problem: Activation functions are chosen heuristically before training
- Approach: Derive activation functions by optimizing correlation-based objectives
- Key finding: Swish-like activations emerge naturally from first principles
- Validation: Theory matches learned activations in neural networks on CIFAR-10

---

## 1. Introduction

### Problem Statement
- Neural networks use fixed activation functions (ReLU, Swish, GELU) chosen before training
- Choices motivated by heuristics: non-saturating gradients, smoothness, biological plausibility
- Missing: principled derivation from task objectives

### Main Contribution
- Derive activation functions from correlation-based optimization
- Provide theoretical framework: Gaussian mixture model with closed-form solutions
- Show Swish emerges naturally as optimal solution for mid-range class separation
- Validate: learned activations in deep networks match theoretical predictions

### Key Results Preview
- Two-class case: ReLU-like shape emerges
- Multi-class with moderate separation: Swish-like activations (*x·σ(βx)*)
- Neural networks (CIFAR-10): Learned activations via backprop match theory
- Layer-specific variation: Earlier layers broader, later layers sharper

### Figures for Introduction
- **Fig 1**: Motivation - various activation functions (ReLU, Swish, GELU) with question: how to derive?
- **Fig 2**: Main result preview - learned activation from 20-class Gaussian mixture showing Swish-like shape

---

## 2. Theoretical Framework

### 2.1 Correlation Objective

**Setup**: 
- Single unit with input *x ~ p(x)*
- Output *f(x)* where *f* is learnable
- *K* classes with labels *y*

**Class-wise correlation**:
```
ρₖ = Corr(f(x), 1[y=k])
```

**Signed objective** (primary):
```
minimize  Σ_{k: ρₖ < 0} ρₖ²  -  Σ_{k: ρₖ > 0} ρₖ²
```

**Key properties**:
- Zero-sum constraint: *Σₖ ρₖ = 0* (automatic from correlation definition)
- Budget constraint: Creates competition between classes
- Normalization: *Var(f(x)) = 1*

### 2.2 Gaussian Mixture Setting

**Assumptions**:
- *K* classes with means *μₖ* evenly spaced on interval
- Equal variances *σ²* and equal priors *p(k) = 1/K*
- Activation *f(x)* parameterized as piecewise-linear with *N* knots

**Training modes**:
1. Sample-based: Monte Carlo sampling, gradient descent on knots
2. Analytic: Closed-form Gaussian integrals for each segment

### 2.3 Analytical Theory

**Decomposition**: *f(x)* from *ρ(x)*:
```
f(x) = ∫₋∞ˣ ρ(x') dx'
```

**Negative part** (low *x*):
- Exponential decay: *ρ(x) ~ exp(-λx)*
- Smooth ODE with boundary condition

**Positive part** (high *x*):
- Maximizing energy given budget
- Well-separated: spike (fastest curvature)
- Mid-range: linear ramp (fastest slope)

**Swish approximation** for mid-range *σ*:
```
f(x) ≈ (x - x₀) · σ(β(x - x₀))
```

### Figures for Theory
- **Fig 3**: Correlation objective illustration - class-wise correlations for 20-class mixture
- **Fig 4**: Theoretical decomposition - *ρ(x)* vs *f(x)* relationship

---

## 3. Methods

### 3.1 Unit-Level Experiments (Gaussian Mixtures)

**Setup**:
- *K* = 2, 8, 20 classes
- Variance sweeps: *σ* = 0.6, 1.0, 10.0
- Piecewise-linear *f(x)* with 33 knots on [-3, 3]
- Training: Sample-based (10k samples/step) vs. Analytic (closed-form)

**Optimization**:
- Adam optimizer
- Learning rate: 1e-2
- Steps: 100-500
- Smoothness regularization (optional)

### 3.2 Neural Network Experiments (CIFAR-10)

**Architectures**:
- VGG-11/13/16: Conv blocks with BN and learnable PWL activations
- ResNet-10/18: Pre-activation blocks with learnable PWL activations

**Learnable Activation Module** (`PiecewiseLinearActivation`):
- Uniform knots on [-3, 3]
- 33 knots (default), learnable knot values *yₛ*
- Per-layer shared (default) or per-channel mode
- Post-step projection: anchor left knot to zero, L2-normalize (optional)

**Training modes**:
1. **Backprop**: Standard cross-entropy, all parameters optimized end-to-end
2. **Local correlation**: Backbone via CE, activations via correlation objective (two optimizers)

**Hyperparameters**:
- Batch size: 256
- Epochs: 20
- Backbone LR: 1e-3
- Activation LR: 1e-2
- Optimizer: Adam

**Logging**:
- Weights & Biases (`cstein06/activation`)
- Per-epoch: train/val loss, accuracy
- Activation snapshots (per layer)
- Pre-activation histograms (per-class distributions)

### Figures for Methods
- **Fig 5**: Experimental setup diagrams
  - (a) Gaussian mixture configuration
  - (b) Neural network architecture with PWL activations
  - (c) Training modes comparison

---

## 4. Results

### 4.1 Unit-Level Results

#### Two-Class Case (*K=2*)
- **Optimal shape**: ReLU-like
- Near-zero for negative inputs
- Linear increase for positive inputs
- Surprising: expected sigmoid/Heaviside for binary classification
- Reason: correlation objective with zero-sum constraint creates threshold detector

#### Mid-Range Separation (*K=20*, *σ=1.0*)
- **Optimal shape**: Swish-like
- Smooth gating: *f(x) ≈ x · sigmoid(2.5x)*
- Negative *ρₖ* for low classes, positive *ρₖ* for high classes
- Transition region creates sigmoid gating

#### Variance Sweeps
- **Small σ (0.6)**: Sharper, more selective activation
- **Mid σ (1.0)**: Smooth Swish
- **Large σ (10.0)**: Broad, nearly linear with smooth threshold

#### Analytic vs. Sample Training
- Both converge to same shapes
- Analytic faster (closed-form integrals)
- Validates gradient implementation

### 4.2 Neural Network Results

#### VGG-11 Backprop (20 epochs)
- Learned activations: Swish-like across all layers
- Test accuracy: ~88% (comparable to ReLU baseline)
- Clean convergence

#### ResNet-10 Backprop (20 epochs)
- Faster convergence than VGG
- Cleaner activation shapes (pre-activation blocks help)
- Test accuracy: ~90%

#### Activation Evolution
- **Early training**: Near-linear (initialized as ReLU)
- **Mid training**: Sigmoid gating appears
- **Late training**: Stable Swish with layer-specific β

#### Layer-Wise Variation
- **Early layers (0-2)**: Broad, smooth (β ~ 1.5)
- **Mid layers (3-6)**: Steeper slopes (β ~ 2.5)
- **Late layers (7-9)**: Nearly ReLU (already good features)

### 4.3 Swish Fitting

Fit learned *f(x)* to Swish family: *f(x) = (x - x₀) · σ(β(x - x₀))*

**Results**:
- 20-class, *σ=1.0*: β ≈ 2.5, x₀ ≈ 0, R² > 0.99
- Small *σ*: Larger β (sharper)
- Large *σ*: Smaller β (smoother)

**Neural networks**:
- Layer-specific β values
- Early layers: β ~ 1.5-2.0
- Late layers: β ~ 3.0-5.0

### Figures for Results
- **Fig 6**: Unit-level results
  - (a) Two-class: ReLU-like shape
  - (b) 20-class mid-σ: Swish-like shape with Swish fit overlay
  - (c) Variance sweep: σ = 0.6, 1.0, 10.0
  
- **Fig 7**: Neural network learned activations
  - (a) VGG-11 layer 0 evolution over training
  - (b) ResNet-10 layer 3 evolution
  - (c) Final activations across all layers
  
- **Fig 8**: Layer-wise comparison
  - Snapshots from ResNet-10 layers 0, 3, 6, 7 showing progression from broad to sharp

---

## 5. Discussion

### 5.1 Why Swish Emerges

Swish (*x · sigmoid(βx)*) is optimal because:
- **Correlation budget**: Zero-sum constraint creates competition
- **Smooth gating**: Sigmoid provides differentiable threshold
- **Linear scaling**: Higher *x* → higher output (good for deep networks)
- Not hand-designed—derived from first principles

### 5.2 Connection to Backpropagation

Correlation objective approximates cross-entropy gradient for activation functions when:
- Per-class input distributions are roughly Gaussian
- Classes are moderately separated
- Network not too deep (earlier layers benefit most)

CIFAR-10 pre-activations are approximately Gaussian:
- Batch normalization encourages Gaussian statistics
- Central limit theorem: sum of many inputs → Gaussian
- Empirical histograms confirm

### 5.3 Relationship to Prior Work

**Swish** (Ramachandran et al., 2017):
- Discovered via neural architecture search
- Our work: derived from first principles

**Adaptive activations** (general):
- Many papers learn activations via backprop
- Our contribution: theoretical grounding with Gaussian mixture analysis and closed-form solutions

**Correlation learning**:
- Related to Hebbian-like rules
- Our formulation: explicit correlation objective with normalization and budget constraint

### 5.4 Limitations

- Gaussian mixture assumption (though CIFAR-10 validates this)
- Piecewise-linear parameterization (could try splines, neural networks)
- Limited to single-unit analysis (though extends to layers empirically)
- Local correlation training still being stabilized

### 5.5 Future Work

- Extend to non-Gaussian input distributions
- Formal proof of Swish optimality for Gaussian mixtures
- Try on larger datasets (ImageNet) and other domains (language models)
- Per-channel vs. shared activations: memory/expressiveness tradeoff
- Biological plausibility: correlation learning as Hebbian-like rule
- Connection to information theory (mutual information, capacity)

---

## 6. Conclusion

We presented a principled framework for deriving activation functions from correlation-based optimization. Our key contributions:

1. **Theoretical framework**: Gaussian mixture model with correlation objective yields closed-form solutions
2. **Swish emergence**: Mid-range class separation naturally produces Swish-like activations
3. **Neural network validation**: Learned activations in deep networks match theoretical predictions
4. **Interpretability**: Clear understanding of why certain shapes emerge (budget constraints, smooth gating)

This work provides theoretical grounding for understanding and designing activation functions, connecting optimization objectives to emergent functional forms.

---

## References

### Key Citations Needed

**Activation functions**:
- Ramachandran et al. (2017): Swish - discovered via NAS
- Hendrycks & Gimpel (2016): GELU
- Glorot et al. (2011): ReLU
- Nair & Hinton (2010): ReLU in deep belief nets

**Adaptive/learnable activations**:
- Agostinelli et al. (2014): Learning activation functions
- Various recent papers on learnable activations

**Correlation-based learning**:
- Hebbian learning literature
- Unsupervised/self-supervised learning

**Neural network architectures**:
- Simonyan & Zisserman (2014): VGG
- He et al. (2016): ResNet

**Datasets**:
- Krizhevsky (2009): CIFAR-10

---

## Figures Summary

### Complete Figure List (8 figures)

1. **Fig 1**: Motivation - common activation functions
   - Source: Create new diagram or use literature
   
2. **Fig 2**: Main result preview - 20-class learned activation
   - Source: `/Users/cstein/code/activation_function/figures/analytic_smoke.png`
   
3. **Fig 3**: Correlation objective illustration
   - Source: Create from theory or adapt existing
   
4. **Fig 4**: Theoretical decomposition (ρ vs f)
   - Source: `/Users/cstein/code/activation_function/figures/analytic_smoke_rho_fit.png`
   
5. **Fig 5**: Experimental setup (composite)
   - Source: Create new diagram
   
6. **Fig 6**: Unit-level results (composite)
   - (a) Two-class: `/Users/cstein/code/activation_function/figures/analytic_2classes.png`
   - (b) 20-class with fit: `/Users/cstein/code/activation_function/figures/analytic_smoke_swish_fit.png`
   - (c) Sigma sweep: `/Users/cstein/code/activation_function/figures/compare_sigs.png`
   
7. **Fig 7**: NN learned activations evolution
   - (a) Evolution: `/Users/cstein/code/activation_function/figures/analytic_smoke_fx_over_steps.png` (adapt for NN)
   - (b) Evolution: Similar
   - (c) Final layers: Use WandB snapshots from `activations_4j06yful/`
   
8. **Fig 8**: Layer-wise comparison
   - Sources: 
     - Layer 0: `/Users/cstein/code/activation_function/figures/activations_4j06yful/activations_layer_0.png`
     - Layer 3: `/Users/cstein/code/activation_function/figures/activations_4j06yful/activations_layer_3.png`
     - Layer 6: `/Users/cstein/code/activation_function/figures/activations_4j06yful/activations_layer_6.png`
     - Layer 7: `/Users/cstein/code/activation_function/figures/activations_4j06yful/activations_layer_7.png`

### Additional Available Figures (for supplementary)
- Pre-activation histograms: `hists_layer_*.png`
- Comparison plots: `quick_compare.png`
- Various sigma sweeps and fits

---

## Notes for Draft Generation

### Writing Guidelines
- Target: 8-10 pages for ICML format
- Clear problem statement in intro
- Enough methods detail to reproduce
- Highlight key results with figure references
- Discussion: interpret results, acknowledge limitations
- Define notation clearly
- Use proper LaTeX math environments

### LaTeX Specifics
- Document class: `\documentclass{article}` with `\usepackage{icml2025}`
- Figures: `\begin{figure}...\end{figure}` with captions
- Math: Display equations in `align` or `equation` environments
- Citations: `\cite{key}` with BibTeX entries

### Content Priorities
1. Core contribution: correlation objective → Swish derivation
2. Theoretical validation: Gaussian mixture with closed-form solutions
3. Empirical validation: NN experiments match theory
4. Clear figures showing emergence of Swish

### Gaps to Address
- Need to search for/create motivation figure (Fig 1)
- Need to create experimental setup diagram (Fig 5)
- May need to adapt some unit-level evolution plots for NN context
