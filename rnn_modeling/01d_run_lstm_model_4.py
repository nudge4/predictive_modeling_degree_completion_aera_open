import sys
assert sys.version_info >= (3, 5)

import sklearn
assert sklearn.__version__ >= "0.20"

import tensorflow as tf
from tensorflow import keras
assert tf.__version__ >= "2.0"

import os
os.chdir("C:/Users/ys8mz/Box Sync/Predictive Models of College Completion (VCCS)/intermediate_files")

if not tf.config.list_physical_devices('GPU'):
    print("No GPU was detected. LSTMs and CNNs can be very slow without a GPU.\n")

# Other common imports
import pickle
import numpy as np
import pandas as pd
from sklearn.metrics import roc_auc_score

# to make this script's output stable across runs
np.random.seed(42)
tf.random.set_seed(42)


def generate_batches(X, X2, y):
    while True:
        for i in range(len(X)):
            yield ([X[i][np.newaxis,:,:], X2[np.newaxis,i,:]], y[np.newaxis,i])

def generate_test_batches(X, X2):
    while True:
        for i in range(len(X)):
            yield [X[i][np.newaxis,:,:], X2[np.newaxis,i,:]]


X_train_part1 = pickle.load(open("lstm_data/part1_train_X.p", "rb"))
X_valid_part1 = pickle.load(open("lstm_data/part1_valid_X.p", "rb"))
X_test_part1 = pickle.load(open("lstm_data/part1_test_X.p", "rb"))
X_train_part2 = np.load("lstm_data/part2_train_X.npy")
X_valid_part2 = np.load("lstm_data/part2_valid_X.npy")
X_test_part2 = np.load("lstm_data/part2_test_X.npy")
y_train = np.load("lstm_data/train_y.npy")
y_valid = np.load("lstm_data/valid_y.npy")
y_test = np.load("lstm_data/test_y.npy")


class EarlyStopByAUC(keras.callbacks.Callback):
    
    def __init__(self, y, nb, verbose = 1, patience = 5, delta = 1e-4, model_name='lstm_model_1'):
        super(keras.callbacks.Callback, self).__init__()
        self.best_score = None
        self.counter = 0
        self.validation_data_y = y
        self.nb = nb
        self.verbose = verbose
        self.patience = patience
        self.delta = delta
        self.model_name = model_name
        self.train_loss = []
        self.val_loss = []

    def on_epoch_end(self, epoch, logs={}):
        predict = np.asarray(self.model.predict_generator(generate_test_batches(X_valid_part1, X_valid_part2), steps=self.nb))
        score = roc_auc_score(self.validation_data_y, predict)
        loss_1 = self.model.evaluate_generator(generate_batches(X_train_part1, X_train_part2, y_train), steps=len(X_train_part1))
        loss_2 = self.model.evaluate_generator(generate_batches(X_valid_part1, X_valid_part2, y_valid), steps=len(X_valid_part1))
        self.train_loss.append(loss_1)
        self.val_loss.append(loss_2)
        pd.DataFrame({'train_loss': self.train_loss,
                      'val_loss': self.val_loss}).loc[:,['train_loss', 'val_loss']]\
        .to_csv("output/running_learning_curve_{}.csv".format(self.model_name), index=False)
        if self.verbose > 0:
            print("Epoch {0}: val_auc = {1}".format(epoch+1, score))
        if self.best_score is None:
            self.best_score = score
            self.model.save("output/{}.h5".format(self.model_name))
        elif score < self.best_score + self.delta:
            self.counter += 1
            if self.counter >= self.patience:
                self.model.stop_training = True
        else:
            self.best_score = score
            self.counter = 0
            self.model.save("output/{}.h5".format(self.model_name))


#############
#Fit Model 10
#############
print("\n\n\n")
print("Fitting Model 10:")
np.random.seed(42)
tf.random.set_seed(42)
part_1 = keras.models.Sequential([keras.layers.LSTM(20, return_sequences=True, input_shape=[None, 19]),
                                  keras.layers.LSTM(20, input_shape=[None, 20])])
part_2 = keras.models.Sequential([keras.layers.Input(shape=(55,))])
model_concat = keras.layers.concatenate([part_1.output, part_2.output], axis=-1)
model_concat = keras.layers.Dense(20, activation='sigmoid')(model_concat)
model_concat = keras.layers.Dense(1, activation='sigmoid')(model_concat)
model = keras.Model(inputs=[part_1.input, part_2.input], outputs=model_concat)
optimizer = keras.optimizers.Adam(lr=0.0001) # default learning rate value for Adam is 0.001
model.compile(loss='binary_crossentropy', optimizer=optimizer)
gen = generate_batches(X_train_part1, X_train_part2, y_train)
callbacks = [EarlyStopByAUC(y_valid, len(X_valid_part1), model_name="lstm_model_10")]
history = model.fit_generator(gen, steps_per_epoch = len(X_train_part1), 
                              epochs=500,verbose=0,
                              validation_data=generate_batches(X_valid_part1, X_valid_part2, y_valid),
                              validation_steps=len(X_valid_part1),
                              callbacks=callbacks)
history_df = pd.DataFrame({'train_loss': history.history["loss"],
                           'val_loss': history.history["val_loss"]}).loc[:,['train_loss', 'val_loss']]
history_df.to_csv("output/final_learning_curve_lstm_model_10.csv", index=False)

# Estimate the performance of the best model on the held-out test set
saved_model = keras.models.load_model("output/lstm_model_10.h5")
test_auc = \
roc_auc_score(y_test, np.asarray(saved_model.predict_generator(generate_test_batches(X_test_part1, X_test_part2),
                                                               steps=len(X_test_part1))))
print("\nLSTM Model 10:\nC-statistic = {}\n\n".format(test_auc))


#############
#Fit Model 11
#############
print("\n\n\n")
print("Fitting Model 11:")
np.random.seed(42)
tf.random.set_seed(42)
part_1 = keras.models.Sequential([keras.layers.LSTM(55, return_sequences=True, input_shape=[None, 19]),
                                  keras.layers.LSTM(55, input_shape=[None, 20])])
part_2 = keras.models.Sequential([keras.layers.Input(shape=(55,))])
model_concat = keras.layers.concatenate([part_1.output, part_2.output], axis=-1)
model_concat = keras.layers.Dense(20, activation='sigmoid')(model_concat)
model_concat = keras.layers.Dense(1, activation='sigmoid')(model_concat)
model = keras.Model(inputs=[part_1.input, part_2.input], outputs=model_concat)
optimizer = keras.optimizers.Adam(lr=0.0001) # default learning rate value for Adam is 0.001
model.compile(loss='binary_crossentropy', optimizer=optimizer)
gen = generate_batches(X_train_part1, X_train_part2, y_train)
callbacks = [EarlyStopByAUC(y_valid, len(X_valid_part1), model_name="lstm_model_11")]
history = model.fit_generator(gen, steps_per_epoch = len(X_train_part1), 
                              epochs=500,verbose=0,
                              validation_data=generate_batches(X_valid_part1, X_valid_part2, y_valid),
                              validation_steps=len(X_valid_part1),
                              callbacks=callbacks)
history_df = pd.DataFrame({'train_loss': history.history["loss"],
                           'val_loss': history.history["val_loss"]}).loc[:,['train_loss', 'val_loss']]
history_df.to_csv("output/final_learning_curve_lstm_model_11.csv", index=False)

# Estimate the performance of the best model on the held-out test set
saved_model = keras.models.load_model("output/lstm_model_11.h5")
test_auc = \
roc_auc_score(y_test, np.asarray(saved_model.predict_generator(generate_test_batches(X_test_part1, X_test_part2),
                                                               steps=len(X_test_part1))))
print("\nLSTM Model 11:\nC-statistic = {}\n\n".format(test_auc))