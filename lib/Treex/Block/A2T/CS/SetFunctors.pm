package Treex::Block::A2T::CS::SetFunctors;

use Moose;
use Treex::Core::Common;
use Treex::Block::Write::ConllLike;
use Treex::Tool::IO::Arff;
use autodie;
use Treex::Tool::ML::MLProcess;

extends 'Treex::Core::Block';

# TectoMT shared directory
Readonly my $TMT_SHARE => "$ENV{TMT_ROOT}/share/";

# files related to the trained model (within the TectoMT shared directory)
has 'model_dir'         => ( is => 'ro', isa => 'Str', default => "data/models/functors/cs/" );
has 'model'             => ( is => 'ro', isa => 'Str', default => 'model.dat' );
has 'plan_template'     => ( is => 'ro', isa => 'Str', default => 'plan.template' );
has 'filtering_ff_data' => ( is => 'ro', isa => 'Str', default => 'ff-data.dat' );
has 'filtering_if_data' => ( is => 'ro', isa => 'Str', default => 'if-data.dat' );
has 'lang_conf'         => ( is => 'ro', isa => 'Str', default => 'st-cs.conf' );

# functors loaded from the result of ML process, works as a FIFO (is first filled with the whole document, then subsequently emptied)
has '_functors' => ( traits => ['Array'], is => 'ro', default => sub { [] } );

# download shared files if necessary
override 'get_required_share_files' => sub {

    my ($self) = @_;

    my @files = map { $_ = $self->model_dir . $_ }
        ( $self->model, $self->plan_template, $self->filtering_if_data, $self->filtering_ff_data, $self->lang_conf );
    return @files;
};

override 'process_document' => sub {

    my ( $self, $document ) = @_;
    my $mlprocess = Treex::Tool::ML::MLProcess->new( plan_template => $TMT_SHARE . $self->model_dir . $self->plan_template );

    my $temp_conll = $mlprocess->create_temp_file();
    my $out        = $mlprocess->create_temp_file();

    log_info("Output file: $out");

    # print out data in pseudo-conll format for the ml-process program
    log_info( "Writing the CoNLL-like data to " . $temp_conll );
    my $conll_writer = Treex::Block::Write::ConllLike->new(
        to       => $temp_conll->filename,
        language => $self->language,
        selector => $self->selector
    );
    $conll_writer->process_document($document);

    # run ML-Process with the specified plan file
    $mlprocess->run(
        {   "CONLL"     => $temp_conll,
            "ARFF-OUT"  => $out,
            "FF-INFO"   => $TMT_SHARE . $self->model_dir . $self->filtering_ff_data,
            "IF-INFO"   => $TMT_SHARE . $self->model_dir . $self->filtering_if_data,
            "MODEL"     => $TMT_SHARE . $self->model_dir . $self->model,
            "LANG-CONF" => $TMT_SHARE . $self->model_dir . $self->lang_conf
        }
    );

    # parse the output file and store the results
    $self->_load_functors( $out, scalar( $document->get_bundles() ) );

    # process all t-trees and fill them with functors
    super;
};

# self fills a t-tree with functors, which must be preloaded in $self->_functors
sub process_ttree {

    my ( $self, $root ) = @_;
    my @functors = @{ shift @{ $self->_functors } };                      # always take results for the first tree, FIFO
    my @nodes = $root->get_descendants( { ordered => 1 } );               # same as for printing in Write::ConllLike

    if ( scalar(@nodes) != scalar(@functors) ) {
        log_fatal( "Expected " . scalar(@nodes) . " functors, got " . scalar(@functors) );
    }
    foreach my $node (@nodes) {
        $node->set_functor( shift @functors );
    }
    return;
}

# Load the functors assigned by the ML process from the ARFF file
sub _load_functors {

    my ( $self, $arff_file, $max_sents ) = @_;
    my $loader = Treex::Tool::IO::Arff->new();
    my $data   = $loader->load_arff( $arff_file->filename );

    my $sentence;
    my $sent_id = 1;

    for my $rec ( @{ $data->{records} } ) {

        while ( $rec->{'sent-id'} != $sent_id and $sent_id <= $max_sents ) {    # move to next non-empty sentence
            push @{ $self->_functors }, $sentence;
            $sentence = [];
            $sent_id++;
        }
        if ( $sent_id > $max_sents ) {
            log_fatal( 'Sentence IDs mismatch in the loaded ARFF file: ' . $arff_file->filename );
        }
        push @{$sentence}, $rec->{'deprel'};
    }
    push @{ $self->_functors }, $sentence;
    return;
}

1;

__END__

=head1 Treex::Block::A2T::CS::SetFunctors

Sets functors in tectogrammatical trees using a pre-trained machine learning model (logistic regression, SVM etc.)
via the ML-Process Java executable with WEKA integration.

=head2 Parameters

All of the file paths have their default value set:

=over

=item model_dir

Pre-trained model directory.

=item model

Name of the trained model file.

=item plan_template

Name of the ML-Process plan file template.

=item filtering_ff_data 

Name of the feature filtering information file.

=item filtering_if_data

Name of the feature removal information file.

=item lang_conf

Name of the feature generation configuration file.

=back

=head2 TODO

Possibly could be made language independent, only with different models for different languages.

=cut

# Copyright 2011 Ondrej Dusek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

