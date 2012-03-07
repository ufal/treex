SHELL=bash
# ParseLM example
LANGUAGE=en
INPUT=tune
OUTPUT=input
TRAIN_ME=training_data

all: clean make_data train

make_data: 
	perl scale.pm $(INPUT)
	#perl combine-labels.pl $(OUTPUT) > temp
	perl remove.pl $(OUTPUT) > $(TRAIN_ME)
train: 
	perl SVMTrain.pm $(TRAIN_ME) 15
	#perl SVMTrain.pm $(OUTPUT)
	
clean: 
	rm -f input
