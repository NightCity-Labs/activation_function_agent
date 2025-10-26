# Reference Papers for Quality Benchmarking

High-quality papers on activation functions and related topics for style, structure, and quality reference.

---

## Primary References (Activation Functions)

### 1. Swish: A Self-Gated Activation Function
- **Authors**: Prajit Ramachandran, Barret Zoph, Quoc V. Le
- **Venue**: arXiv 2017 (widely cited, ~3000+ citations)
- **URL**: https://arxiv.org/abs/1710.05941
- **PDF**: https://arxiv.org/pdf/1710.05941.pdf
- **Why**: Seminal work on learned activation functions, excellent experimental design
- **Download**: `curl -o swish_2017.pdf https://arxiv.org/pdf/1710.05941.pdf`

### 2. GELU: Gaussian Error Linear Units
- **Authors**: Dan Hendrycks, Kevin Gimpel
- **Venue**: arXiv 2016 (widely adopted, used in BERT, GPT)
- **URL**: https://arxiv.org/abs/1606.08415
- **PDF**: https://arxiv.org/pdf/1606.08415.pdf
- **Why**: Clear motivation, strong empirical results, widely adopted
- **Download**: `curl -o gelu_2016.pdf https://arxiv.org/pdf/1606.08415.pdf`

### 3. Mish: A Self Regularized Non-Monotonic Activation Function
- **Authors**: Diganta Misra
- **Venue**: arXiv 2019
- **URL**: https://arxiv.org/abs/1908.08681
- **PDF**: https://arxiv.org/pdf/1908.08681.pdf
- **Why**: Recent work, comprehensive benchmarking
- **Download**: `curl -o mish_2019.pdf https://arxiv.org/pdf/1908.08681.pdf`

---

## Secondary References (Writing Quality)

### 4. Attention Is All You Need
- **Authors**: Vaswani et al.
- **Venue**: NeurIPS 2017
- **URL**: https://arxiv.org/abs/1706.03762
- **Why**: Exemplary paper structure and clarity
- **Download**: `curl -o attention_2017.pdf https://arxiv.org/pdf/1706.03762.pdf`

### 5. Batch Normalization
- **Authors**: Ioffe, Szegedy
- **Venue**: ICML 2015
- **URL**: https://arxiv.org/abs/1502.03167
- **Why**: Clear problem statement, strong empirical validation
- **Download**: `curl -o batchnorm_2015.pdf https://arxiv.org/pdf/1502.03167.pdf`

---

## Download All

```bash
cd /Users/cstein/code/activation_function_agent/paper/references/

# Primary references
curl -o swish_2017.pdf https://arxiv.org/pdf/1710.05941.pdf
curl -o gelu_2016.pdf https://arxiv.org/pdf/1606.08415.pdf
curl -o mish_2019.pdf https://arxiv.org/pdf/1908.08681.pdf

# Secondary references
curl -o attention_2017.pdf https://arxiv.org/pdf/1706.03762.pdf
curl -o batchnorm_2015.pdf https://arxiv.org/pdf/1502.03167.pdf
```

---

## Usage in Improvement Workflow

These papers serve as benchmarks for:
- **Writing style**: Clarity, conciseness, technical precision
- **Structure**: How to organize methods, results, discussion
- **Argumentation**: How to present and support claims
- **Figures**: Quality and presentation standards
- **Experimental design**: Comprehensive evaluation strategies

