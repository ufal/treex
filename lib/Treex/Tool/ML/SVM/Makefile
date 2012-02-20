SHELL=bash
# ParseLM example
LANGUAGE=en
INPUT=tune
TRAIN_FILE=input2


all: clean make_data train

make_data: 
	perl scale.pm $(INPUT)

train: 
	perl SVMTrain.pm $(TRAIN_FILE)
	
clean: 
	rm -f input
