---
marp: true
---

theme: default
paginate: true
---

# The Essence of Backpropagation

---

## A Neural Network is Just a Program

- Forward pass = run the program
- Backward pass = compute gradients of every intermediate
- Training = update parameters with gradients

<!-- notes:
Karpathy often emphasizes the "program" analogy.
-->

---

## Tiny Autograd Engine (Pseudo‑Python)

```python
class Value:
    def __init__(self, data, grad=0):
        self.data = data
        self.grad = grad
        self._backward = lambda: None

    def __add__(self, other):
        out = Value(self.data + other.data)
        def _backward():
            self.grad += 1 * out.grad
            other.grad += 1 * out.grad
        out._backward = _backward
        return out

for step in range(1000):
    loss = model(x).mse(y)
    loss.backward()
    model.update(lr=1e-3)
