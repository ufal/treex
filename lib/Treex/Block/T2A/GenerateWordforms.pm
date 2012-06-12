package Treex::Block::T2A::GenerateWordforms;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );
has 'generator_class' => ( is => 'rw', required => 1 );
has 'generator' => ( is => 'rw' );

sub process_start {
    my $self = shift;

    eval "use ".$self->generator_class;
#        or log_fatal "Cannot use generator class ".$self->generator_class;


    $self->set_generator(eval $self->generator_class."->new(); ")
        or log_fatal "Cannot initiate generator from class ".$self->generator_class;

    return;
}


sub process_anode {
    my ( $self, $anode ) = @_;

    $anode->set_form( $anode->lemma );

    if ( $anode->tag and $anode->tag !~ /^[!ZJR]/ ) {

        my ($form_info) = $self->generator->forms_of_lemma(
            $anode->lemma,
            { tag_regex => $anode->tag}
        );

        if ( $form_info ) {
            $anode->set_form( $form_info->get_form() );
            $anode->set_tag( $form_info->get_tag() );
#            print $anode->lemma." + ".$anode->tag." --> ".$anode->form."\n";
        }

        else {
#            print "possible fallbacks for lemma=".$anode->lemma." tag=".$anode->tag."\n";
            foreach my $form_info ( $self->generator->forms_of_lemma($anode->lemma) ) {
#                print "   ".$form_info->get_form." ".$form_info->get_tag."\n";
            }
        }
    }
    return;
}


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::GenerateWordforms

=item DESCRIPTION

Given a language and a morphological generator class, it generates word
forms for each lemma and tag mask.

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
