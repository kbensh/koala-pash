#!/usr/bin/env python3

import sys
import numpy as np
import pickle
import os

with open(sys.argv[1], 'rb') as file:
    model = pickle.load(file)
multi_class = sys.argv[2]
n_classes = int(sys.argv[3])

if model.warm_start:
    warm_start_coef = getattr(model, "coef_", None)
else:
    warm_start_coef = None
if warm_start_coef is not None and model.fit_intercept:
    warm_start_coef = np.append(
        warm_start_coef, model.intercept_[:, np.newaxis], axis=1
    )
tmp = os.environ.get('OUT')
if multi_class == "multinomial":
    filepath = os.path.join(tmp, 'classes.obj')
    with open(filepath, 'wb') as file:
        pickle.dump([None], file)
    warm_start_coef = [warm_start_coef]
if warm_start_coef is None:
    warm_start_coef = [None] * n_classes

filepath = os.path.join(tmp, 'warm_start_coef.obj')
with open(filepath, 'w+b') as file:
    pickle.dump(warm_start_coef, file)
