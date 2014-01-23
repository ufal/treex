package Treex::Block::T2A::EN::IndefArticlePhonetics;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_atree {

    my ( $self, $aroot ) = @_;
    my @anodes = $aroot->get_descendants( { ordered => 1 } );

    for ( my $i = 0; $i < @anodes - 1; ++$i ) {
        next if ( $anodes[$i]->lemma ne 'a' );
        my $next_form = lc( $anodes[ $i + 1 ]->form // $anodes[ $i + 1 ]->lemma );

        # only vowels (include mute 'h' and avoid 'ju' and 'w')
        # TODO: how do we distinguish abbreviations?
        if ( $next_form =~ /^([aeiou]|hon|hour|herb|heir)/ and $next_form !~ /^(uni|us[ei]|one|uto|euro)/ ) {
            $anodes[$i]->set_form('an');
        }
    }
    return;
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::EN::IndefArticlePhonetics

=head1 DESCRIPTION

The form of the indefinite article `a' is changed as `an' if it precedes vowels.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
