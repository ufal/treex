package Treex::Tool::MLFix::ScikitLearn;

use Moose;
use File::Temp qw(tempfile);
use Treex::Core::Common;
use Treex::Tool::Python::RunFunc;
use utf8;

extends 'Treex::Tool::MLFix::Model';

has model_dir => (
	is				=> 'ro',
	isa				=> 'Str',
	default			=> 'data/models/mlfix/',
	documentation	=> 'Location of the model file'
);

has model_file => (
	is				=> 'ro',
	isa 			=> 'Str',
	required		=> '1',
	documentation	=> 'Model filename'
);

has lib_dir => (
	is				=> 'ro',
	isa				=> 'Str',
	default			=> 'installed_tools/mlfix/'
);

has tmp_dir => (
	is				=> 'ro',
	isa				=> 'Str',
	default			=> '/tmp',
	documentation	=> 'directory, where the tmp files are stored to avoid passing long string arguments to the python bipipe'
);

has _python => (
    is 		=> 'ro',
    lazy 	=> 1,
    builder => '_build_python',
);

has _command => (
	is		=> 'rw',
	isa		=> 'Str',
	lazy	=> 1,
	builder => '_build_command'
);

## INITIALIZATION ##

my $INIT = <<INIT;
import os, sys
import codecs
import datetime
lib_path = os.path.abspath("%s")
sys.path.append(lib_path)
import model
m = model.loadModel("%s")
INIT

sub _build_python {
    my ($self) = @_;
    my $python = Treex::Tool::Python::RunFunc->new();

	my $lib_path = require_file_from_share($self->lib_dir . 'model.py');
	$lib_path =~ s/model\.py//;	
	my $model_path = require_file_from_share($self->model_dir.$self->model_file);
	my $command = sprintf($INIT, $lib_path, $model_path);
	$python->command($command);

    return $python;
}

sub _build_command {
	my ($self) = @_;

	my $COMMAND = <<COMMAND;
fh = codecs.open("%s", "rb", "UTF-8")
feature_names = fh.readline().rstrip("\\n").split("\\t")
x_all = []
res = []
while True:
    line = fh.readline().rstrip("\\n")
    if not line:
        break
    feat_values = line.split("\\t")
    x = dict()
    for i in range(len(feature_names)):
        x.update({feature_names[i]:feat_values[i]})
    x_all.append(x)
fh.close()
try:
    sys.stderr.write(str(datetime.datetime.now().time()) + ": started predicting\\n")
    scores_all = m.predict_proba(x_all)
    sys.stderr.write(str(datetime.datetime.now().time()) + ": stopped predicting (predict_proba)\\n")
    res = [sorted(zip(m.get_classes(), line), key=(lambda x: x[1]), reverse=True) for line in scores_all]
except (NotImplementedError, AttributeError):
    scores_all = m.predict(x_all)
    sys.stderr.write(str(datetime.datetime.now().time()) + ": stopped predicting (predict))\\n")
    res = [zip([line], [1]) for line in scores_all]
res = [filter(lambda x: x[1] != 0, line) for line in res]
print '###'.join(['##'.join([';'.join([str(key) + ':' + str(item) for key, item in pred[0].iteritems()]) + '#' + str(pred[1]) for pred in line]) for line in res])
COMMAND

	return $COMMAND;
}

sub BUILD {
    my ($self) = @_;
    $self->_python;
}

## FOR RUNTIME ##

sub _get_predictions_array {
	my ($self, $instances) = @_;

    my @target_names = @{ $self->config->{predict} };

    my ($tmp_fh, $tmp_filename) = tempfile("python.XXXXX", DIR => $self->tmp_dir, UNLINK => 1);
    #my $tmp_filename = "/a/LRC_TMP/varis/mlfix/tmp.txt";
    #open(my $tmp_fh, ">", $tmp_filename) or die "cannot open tmp.txt";
    binmode($tmp_fh, ":encoding(UTF-8)");
    print $tmp_fh (join "\t", @{ $self->config->{features} }) . "\n";
	foreach my $instance_info (@$instances) {
#	    foreach my $feature (@{ $self->config->{features} }) {
#    	    print $tmp_fh "$feature\#\#\#$instance_info->{$feature}\t" if defined $instance_info->{$feature};
#	    }
#		print $tmp_fh "\n";
        print $tmp_fh (join "\t", map { defined $instance_info->{$_} ? $instance_info->{$_} : ""} @{ $self->config->{features} }) . "\n";
	}
    $tmp_fh->flush();

    my $command = sprintf($self->_command, $tmp_filename) . "\n";
    my $output =  $self->_python->command($command);
	#log_info("$output");
    close($tmp_fh);

    my $predictions_array = [];
	#open(my $str_fh, '<', \$output) or die "Cannot open file handle on string $output";
	
    my $line_number = 0;
	# read prediction string for each $instance
	#while (<$str_fh>) {
    for my $line (split /\#\#\#/, $output) {
        #log_info("LINE: $line");

		my $predictions = {};

		# process the prediction string
		foreach my $pred_str (split /\#\#/, $line) {
            #log_info("PRED_STR: $pred_str");
			my ($dict_str, $score) = split /\#/, $pred_str;
			my @entries = split /\;/, $dict_str;
			my %pred = ();
			
			# return the original value of the instance as default
			foreach my $new_name (@target_names) {
				my $old_name = $new_name;
				$old_name =~ s/new/old/;
				$pred{ $new_name } = $instances->[$line_number]->{ $old_name };
			}
		
			foreach my $entry (@entries) {
    	        my ($key, $value) = split /\:/, $entry;
	            $pred{ $key } = $value;
			}

			my $pred_key = join(";", map { $pred{$_} } @target_names);
			$predictions->{"$pred_key"} = $score;
            log_debug("$pred_key : $score");
			
		}
		push @$predictions_array, $predictions;
        $line_number++;
	}

	return $predictions_array;
}


sub _get_predictions {
	my ($self, $instance_info) = @_;

	my $instances = [$instance_info];
	my $predictions_array = $self->_get_predictions_array($instances);
	
	return $predictions_array->[0];
	
}

#	my @target_names = @{ $self->config->{predict} };
#
#	my ($tmp_fh, $tmp_filename) = tempfile("python.XXXXX", DIR => $self->tmp_dir, UNLINK => 1);
#	binmode($tmp_fh, ":encoding(UTF-8)");
#	foreach my $feature (@{ $self->config->{features} }) {
#		print $tmp_fh "$feature\t$instance_info->{$feature}\n" if defined $instance_info->{$feature};
#	}
#	$tmp_fh->flush();
#
#	#my @features = map{ $_ . "=" . $instance_info->{$_} } @{ $self->config->{features} };
#	#my @features_esc = map { $_ =~ s/\'/\\\'/g } @features;
#	#my $features_str = "{'" . (join "\',\'", map{ $_ =~ s/=/\'\:\'/} @features_esc) . "'}";
#
#	my $command	= sprintf($self->_command, $tmp_filename) . "\n";
#	my $output =  $self->_python->command($command);
#	#log_info("$output");
#	close($tmp_fh);
#	
#	my $predictions = {};
#
#	# process the output string
#	foreach my $pred_str (split /\#\#/, $output) {
#		#log_info("$pred_str");
#		
#		my ($dict_str, $score) = split /\#/, $pred_str;
#		#log_info("$dict_str => $score");
#
#		my @entries = split /\;/, $dict_str;
#		my %pred = ();
#
#		# we return original value for the instances that are not predicted by the model
#		foreach my $new_name (@target_names) {
#			my $old_name = $new_name;
#			$old_name =~ s/new/old/;
#			$pred{ $new_name } = $instance_info->{ $old_name };
#		}
#
#		#log_info("old: " . join(";", map { $pred{$_} } @target_names));
#
#		foreach my $entry (@entries) {
#			my ($key, $value) = split /\:/, $entry;
#			$pred{$key} = $value;
#		}
#
#		my $pred_key = join(";", map { $pred{$_} } @target_names);
#		$predictions->{"$pred_key"} = $score;
#	}
#
#	return $predictions;
#}

1;

=head1 NAME

Treex::Tool::MLFix::Model -- class for Python ScikitLearn models for MLFix corrections

=head1 DESCRIPTION

=head1 PARAMETERS

=over

=back

=head1 AUTHOR

Dušan Variš <varis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


