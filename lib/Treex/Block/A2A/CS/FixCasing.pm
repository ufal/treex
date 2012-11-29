package Treex::Block::A2A::CS::FixCasing;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ( $self, $dep, $gov ) = @_;

    my $endep = $self->en($dep);
    if ( defined $dep->ord && $dep->ord != 1
        && defined $endep
        && defined $endep->ord && $endep->ord != 1
        && $dep->form ne $endep->form
    ) {
        my $new_form = lc $dep->form;
        my $dofix = 0;
        
        my $form_imatches = lc($dep->form) eq lc($endep->form);
        # TODO simple lemmas
        my $lemma_imatches = lc($dep->lemma) eq lc($endep->lemma);
        
        if ($form_imatches) {
            $new_form = $endep->form;
            $dofix = 1;
        }
        elsif ($lemma_imatches) {
            my $old_form = $dep->form;
            my $en_form = $endep->form;

            if ($en_form =~ /^(\p{isLower}*)$/) {
                # apple
                # new_form already is lc'd
                # $new_form = lc $new_form; 
            }
            elsif ($en_form =~ /^(\p{isUpper}{isLower}*)$/) {
                # Apple
                $new_form = ucfirst $new_form;
            }
            elsif ($en_form =~ /^(\p{isUpper}*)$/) {
                # APPLE
                $new_form = uc $new_form;
            }
            else {
                # something like iPod, VMware
                # (note that the form DOES NOT imatch)
                my $common_length =
                    length($new_form) < length($en_form)
                    ? length($new_form) : length($en_form);
                my $form_builder = '';
                for (my $char = 0; $char < $common_length; $char++) {
                    my $en_char = substr $en_form, $char, 1;
                    my $cs_char = substr $new_form, $char, 1;
                    my $chars_match = $cs_char eq $en_char;
                    my $chars_imatch = lc ($cs_char) eq lc ($en_char);
                    if ( !$chars_match && $chars_imatch ) {
                        $cs_char = $en_char;
                    }
                    $form_builder .= $cs_char;
                }
                $form_builder .= substr $new_form, $common_length;
                $new_form = $form_builder;
            }

            $dofix = $new_form ne $old_form;
        }

        if ($dofix) {
            $self->logfix1( $dep, "Casing" );
            $dep->set_form($new_form);
            $self->logfix2($dep);
        }
    }
}

1;

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CS::FixCasing

=head1 DESCRIPTION


=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
