# -*- coding: utf-8 -*-
"""
Created on Sun Jan 19 21:56:05 2020

@author: ys8mz
"""

## Repeat running this script using the different regularization strength parameter (C), with increasing finer scale, in order to find the optimal C value that results in no meaningful loss of performance

import pickle
import numpy as np
from multiprocessing import Pool
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score

input_fpath = "C:\\Users\\ys8mz\\Box Sync\\Predictive Models of College Completion (VCCS)\\intermediate_files\\"
output_fpath = input_fpath + "lasso_cv_auc\\"

class Lasso_Evaluator(object):
    
    def __init__(self, fold_num, grid_val):                                                                                                           
        self.fold_num = fold_num
        self.grid_val = grid_val
    
    def load_data(self):
        self.X1,self.y1,self.X2,self.y2 = pickle.load(open(input_fpath + "fold_{}.p".format(self.fold_num), "rb"))
        
    def evaluate(self):
        for C in self.grid_val:
            lr = LogisticRegression(penalty='l1', C=C, solver="saga", max_iter=10000)
            lr.fit(self.X1,self.y1)
            auc_val = np.round(roc_auc_score(self.y2, lr.predict_proba(self.X2)[:,1]), 4)
            print("C={}, fold_num={}: auc={}".format(C, self.fold_num, auc_val))
            pickle.dump(auc_val, open(output_fpath + "auc_{}_fold_{}.p".format(C,self.fold_num), "wb"))            
        

def lasso_evaluator_wrapper(q):
    # grid_val = [10.**i for i in list(range(-5,3)) + [5]]
    # grid_val = [0.02,0.03,0.04,0.05,0.06,0.07,0.08,0.09]
    # grid_val = [0.011,0.012,0.013,0.014,0.015,0.016,0.017,0.018,0.019]
    # grid_val = [0.0111,0.0112,0.0113,0.0114,0.0115,0.0116,0.0117,0.0118,0.0119]
    # grid_val = [0.01153]
    # grid_val = [1.2, 1.5, 0.45, 0.11] + [0.475] + [0.9,2,4,5.5e-5, 6e-5, 6.5e-5, 7e-5, 0.000175, 0.0004, 0.0006, 0.0011, 0.0012, 0.0013, 0.00275, 0.00425, 0.12, 0.135, 0.17] + [7.5e-05,0.00015,0.0002,0.0003,0.0005,0.00075,0.0015,0.002,0.0025,0.003,0.0035,0.004,0.0045,0.005,0.006,0.007,0.008,0.009,0.023,0.026,0.035,0.055,0.15,0.2,0.25,0.3,0.4,0.5,0.6,0.7,0.8,0.9]
    grid_val = [2.25e-4, 2.5e-4, 2.75e-4]
    le = Lasso_Evaluator(q, grid_val)
    le.load_data()
    le.evaluate()
    
    
if __name__ == '__main__':
    all_folds_num = list(range(1,11))
    pool = Pool(10) # Parallel processing
    pool.map(lasso_evaluator_wrapper, all_folds_num)