package Treex::Block::T2T::SetDefinitenessVW;

use Moose;
use Treex::Core::Common;
use Treex::Block::Print::VWForDefiniteness;
use Treex::Tool::ML::VowpalWabbit::CsoaaLdfClassifier;

extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

has 'model_file' => ( is => 'ro', isa => 'Str', required => 1 );

has 'features_file' => ( is => 'ro', isa => 'Str', required => 1 );

has 'clear_context_after' => ( isa => 'DiscourseBreaks', is => 'ro', default => 'document' );

has 'context_size' => ( isa => 'Int', is => 'ro', default => 30 );

has '_feats' => ( is => 'rw' );

has '_classif' => ( is => 'rw' );


sub process_start {

    my ($self) = @_;

    my $classif = Treex::Tool::ML::VowpalWabbit::CsoaaLdfClassifier->new( { model_path => $self->model_file } );
    $self->_set_classif($classif);

    my $feats = Treex::Block::Print::VWForDefiniteness->new(
        {
            language                => $self->language,
            features_file           => $self->features_file,
            clear_context_after     => $self->clear_context_after,
            context_size            => $self->context_size,
        }
    );
    $self->_set_feats($feats);

    return;
}

sub process_tnode {

    my ( $self, $tnode ) = @_;

    # force-undef definiteness, otherwise the system will think this is the "correct" one
    my $old_definiteness = $tnode->gram_definiteness;
    $tnode->set_gram_definiteness();    

    my ( $feat_str ) = $self->_feats->get_feats_and_class( $tnode );    
    my $predicted = $self->_classif->classify($feat_str);
    if ($predicted) {
        $tnode->set_gram_definiteness($predicted);
    }
    else {
        $tnode->set_gram_definiteness($old_definiteness);  # fallback to "old" definiteness (should never happen)
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::SetDefinitenessVW

=head1 DESCRIPTION

Setting definiteness using the VowpalWabbit linear classifier.

=head1 PARAMETERS

=over

=item model_file

Path to a trained VowpalWabbit model file (in share or plain relative/absolute path).

=item features_file

Path to features configuration file (in YAML format).

=item clear_context_after

When the context activation is reset -- after document or after each sentence (use for unrelated sentences).

=item context_size

Number of words to consider as "contextually activated".

=back 

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
