package Treex::Block::A2A::HI::Lemmatize;
use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;
extends 'Treex::Core::Block';

has 'model_file' => (
    isa => 'Str',
    is => 'rw', 
    default => 'data/models/lemmatizer/hi/hindi.lemma',
    writer => 'set_model_file',
);

has 'model' => (
    isa => 'HashRef',
    is => 'rw',
    required => 0,
    writer => 'set_model',
);

sub process_start {
    my $self = shift;
    $self->set_model_file( Treex::Core::Resource::require_file_from_share( $self->model_file ) );
    open( my $hdl, $self->model_file ) || log_fatal("Cannot read " . $self->model_file );
    binmode $hdl, ":utf8";
    my %model;
    while ( <$hdl> ) {
        chomp;
        my ( $form, @variants ) = split /\t/;
        map { 
            my ( $tag, $lemma ) = split;
            $model{"$form $tag"} = $lemma;
        } @variants;
    }
    close $hdl;
    $self->set_model( \%model );

    return;
}

sub process_zone {
    my ( $self, $zone ) = @_;
    my $a_root = $zone->get_atree;
    foreach my $node ( $a_root->get_descendants() ) {
        my $key = $node->form . " " . $node->tag;
        $node->set_lemma( $self->model->{ $key } // $node->form . "." );
    }

    return;
}

1;

__END__

=head1 NAME

A2A::HI::Lemmatize

Lemmatize tagged Hindi using the model distributed in the package:

http://sivareddy.in/papers/files/hindi-pos-tagger-2.0.tgz

Copyright 2014 Ales Tamchyna <tamchyna@ufal.mff.cuni.cz>

This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README
