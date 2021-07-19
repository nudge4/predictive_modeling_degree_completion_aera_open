# -*- coding: utf-8 -*-
"""
Created on Sun Nov 17 13:52:53 2019

@author: ys8mz
"""


import pickle
from sklearn.linear_model import LinearRegression
import numpy as np
import multiprocessing
import datetime as dt

fpath = "/Users/ys8mz/Box Sync/Predictive Models of College Completion (VCCS)/intermediate_files"


class Term_GPA_and_Credits_Processor(object):
    
    def __init__(self, ftype, indx, ol):
        self.ftype = ftype
        self.indx = indx
        self.ol = ol # outer list, a list of tuples
        self.val_dict = {}
        
    def find_slope(self):
        for t in self.ol:
            vccsid = t[0]
            l = t[1]
            if len(l) < 2:
                self.val_dict[vccsid] = 0
            elif len(l) == 2:
                self.val_dict[vccsid] = l[1] - l[0]
            else:
                slope_l = []
                rsq_l = []
                for i in range(len(l)-2):
                    x = np.array([list(range(i,len(l)))]).T
                    y = l[i:]
                    reg = LinearRegression()
                    reg.fit(x,y)
                    slope_l.append(reg.coef_[0])
                    rsq_l.append(reg.score(x,y))
                    self.val_dict[vccsid] = slope_l[np.argmax(rsq_l)]
    
    def save(self):
        pickle.dump(self.val_dict, open(fpath + "/term_{0}_trend_values/{1}.p".format(self.ftype, self.indx), "wb"))
        
def term_gpa_and_credits_processor_wrapper(q):
    tgcp = Term_GPA_and_Credits_Processor(q[0], q[1], q[2])
    tgcp.find_slope()
    tgcp.save()
    
    
if __name__ == '__main__':
    print("Beginning Time:", dt.datetime.now())
    results_2 = pickle.load(open(fpath + "/results_2.p", "rb"))
    query_list = [results_2[i:(i+int(1e4))] for i in range(0,len(results_2),int(1e4))]
    query_list = [("gpa", indx, q) for indx,q in enumerate(query_list)]
    pool = multiprocessing.Pool(multiprocessing.cpu_count())
    pool.map(term_gpa_and_credits_processor_wrapper, query_list)
    results_1 = pickle.load(open(fpath + "/results_1.p", "rb"))
    query_list = [results_1[i:(i+int(1e4))] for i in range(0,len(results_1),int(1e4))]
    query_list = [("enrl_intensity", indx, q) for indx,q in enumerate(query_list)]
    pool = multiprocessing.Pool(multiprocessing.cpu_count())
    pool.map(term_gpa_and_credits_processor_wrapper, query_list)
    print("End Time:", dt.datetime.now())