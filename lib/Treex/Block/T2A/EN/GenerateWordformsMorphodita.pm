package Treex::Block::T2A::EN::GenerateWordformsMorphodita;

use Moose;
use Treex::Core::Common;
use Ufal::MorphoDiTa;
extends 'Treex::Core::Block';


has 'dict_file' => (
    isa => 'Str',
    is => 'ro',
    default  => 'data/models/morphodita/en/english-morphium-140407-no_negation.dict',
    required => 1
);

has 'skip_tags' => ( isa => 'Str', is => 'ro', default => '' );

has '_morpho' => ( is => 'rw', builder => '_build_morpho', lazy_build => 1 );

has '_out_buffer' => ( is => 'rw', builder => '_build_out_buffer', lazy_build => 1 ); 

sub _build_morpho {
    my ($self) = @_;
    my ($dict_file) = $self->require_files_from_share($self->dict_file);
    return Ufal::MorphoDiTa::Morpho::load($dict_file);
}

sub _build_out_buffer {
    my ($self) = @_;
    return Ufal::MorphoDiTa::TaggedLemmasForms->new();
}



sub process_anode {
    my ( $self, $anode ) = @_;

    return if ( defined( $anode->form ) or not defined( $anode->conll_pos ) );

    my $skip_tags = $self->skip_tags;
    return if ( $anode->conll_pos =~ /$skip_tags/ );    
    
    # try to find the lemma + tag combination in the dictionary  
    my $res = $self->_morpho->generate($anode->lemma, $anode->conll_pos, $Ufal::MorphoDiTa::Morpho::NO_GUESSER, $self->_out_buffer );

    # we found just one matching lemma
    if ( $res == $Ufal::MorphoDiTa::Morpho::NO_GUESSER and $self->_out_buffer->size() == 1 ){
        my $lforms = $self->_out_buffer->get(0);
        my $matches = 0;
        my $form = undef;
        
        # check the found tag/form pairs for perfect tag match 
        # (the generator assumes we've given in a prefix and returns more different tags)
        for (my $i = 0; $i < $lforms->{forms}->size(); $i++) {
            my $ft = $lforms->{forms}->get($i);
            if ( $ft->{tag} eq $anode->conll_pos ){
                $form = $ft->{form};
                $matches++;
            }
        }
        # we found just one matching form
        if ( $matches == 1 ){
            $anode->set_form($form);
        }
    } 
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EN::GenerateWordformsMorphodita

=head1 DESCRIPTION

Generating word forms using MorphoDiTa. Contains pre-trained model settings for English.

This will only set the word form if *just one* matching form is returned by MorphoDiTa generator. 

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
