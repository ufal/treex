package Treex::Tool::ML::VowpalWabbit::Classifier;

use Moose;
use Treex::Tool::ProcessUtils;
use Treex::Core::Common;
use Treex::Core::Resource qw(require_file_from_share);
use Treex::Tool::ML::VowpalWabbit::Util;

# TODO this implemetation does not comply with the classsifier interface
# one or the other should be changed
#with 'Treex::Tool::ML::Classifier';

has 'vw_path' => (is => 'ro', isa => 'Str', required => 1, default => '/net/cluster/TMP/mnovak/tools/vowpal_wabbit/vowpalwabbit/vw');
has '_read_handle'  => ( is => 'rw', isa => 'FileHandle' );
has '_write_handle' => ( is => 'rw', isa => 'FileHandle' );

has 'model_path' => (is => 'ro', isa => 'Str', required => 1);

#has '_last_instance' => (is => 'rw');
#has '_last_result' => (is => 'rw', isa => 'HashRef[Num]');

sub BUILD {
    my ($self) = @_;
    
    my $model_path = $self->_locate_model_file($self->model_path, $self);
    my $command = sprintf "%s -t -i %s -r /dev/stdout 2> /dev/null", $self->vw_path, $model_path;

    my ( $read, $write, $pid ) = Treex::Tool::ProcessUtils::bipipe($command);
    
    $read->autoflush();
    $write->autoflush();    
    $self->_set_read_handle($read);
    $self->_set_write_handle($write);
}

sub _locate_model_file {
    my ($self, $path) = @_;
    
    if (!-f $path) {
        $path = require_file_from_share($path, ref($self));
    }
    log_fatal 'File ' . $path . ' does not exist.' 
        if !-f $path;
    return $path;
}

sub score {
    my ($self, $instance) = @_;

    #if (!defined $self->_last_instance || $self->_last_instance != $instance) {

    my $instance_str = Treex::Tool::ML::VowpalWabbit::Util::format_singleline($instance);
    print {$self->_write_handle} $instance_str . "\n";

    my $fh = $self->_read_handle;
    my $line = <$fh>;
    chomp $line;
    my %scores = map { my ($idx, $score) = split /:/, $_; $idx => $score }
        grep {$_ =~ /:/} split / /, $line;

    return %scores;

    #$self->_set_last_instance($instance);
    #$self->_set_last_result(\%scores);
    #}
    
    #return $self->_last_result->{$y};
}

# TODO this almost the same as Treex::Tool::ML::Classifier::predict => unify it
sub predict {
    my ($self, $instance) = @_;
    my %scores = $self->score($instance);
    my ($best_class) = sort {$scores{$b} <=> $scores{$a} || $a cmp $b} keys %scores;
    return $best_class;
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Tool::ML::VowpalWabbit::Classifier

=head1 DESCRIPTION

A VowpalWabbit multiclass classifier.
Using one-against-all binarization strategy.

=head1 METHODS

=over

=item score

Calculate a score for each possible class.

=item predict

Predicts a class with a highest score.

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz> 

=head1 COPYRIGHT AND LICENCE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
