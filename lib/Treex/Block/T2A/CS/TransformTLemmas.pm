package Treex::Block::T2A::CS::TransformTLemmas;

use Moose;
use Treex::Core::Common;
use Treex::Tools::FSM::Foma;

extends 'Treex::Core::Block';

has '_foma' => ( is => 'rw', builder => '_init_foma' );


# Using TLemmas.xfst located in the same directory as the source!
sub _init_foma {

    my $dir = __FILE__;
    $dir =~ s/\/[^\/]*$//;
    my $foma = Treex::Tools::FSM::Foma->new( work_dir => $dir, grammar => 'TLemmas.xfst' );
    return $foma;
}

sub process_tnode {

    my ( $self, $tnode ) = @_;
    my $old_lemma = $tnode->t_lemma;
    my $numer     = $tnode->get_attr('gram/numertype');
    my $indef     = $tnode->get_attr('gram/indeftype');
    my $functor   = $tnode->functor;
    my $sempos    = $tnode->get_attr('gram/sempos');
    my $new_lemma;

    $indef = $indef ? '+' . $indef : '';
    $numer = $numer ? '+' . $numer : '';
    $functor = $functor =~ m/^(TWHEN|THO|TSIN|TTILL|TFHL|THO|LOC|DIR1|DIR2|DIR3|EXT)$/ ? '+' . $functor : '';

    $functor =~ s/^\+EXT$/+THO/;
    $functor =~ s/^\+ORIG$/+DIR1/;

    # 'jedno střídání' vs. 'jednou vypoví banka konto'
    if ( $old_lemma =~ m/[0-9]/ or ( $numer =~ m/^\+(basic|ord)$/ and $functor =~ m/^\+(THO|TWHEN)$/ and $sempos =~ m/^n/ ) ) {       
        return;
    }

    if ( $indef or $numer or $old_lemma =~ /^(tady|tam|teď|potom|tehdy)$/ ) {
        $new_lemma = $self->_foma->down( $old_lemma . $numer . $indef . $functor );
    }

    # the old lemma was recognized by the grammar -> set new lemma
    if ( $new_lemma and ( $new_lemma ne '???' ) ) {        
        $tnode->set_t_lemma($new_lemma);
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::CS::TransformTLemmas

=head1 DESCRIPTION

Technical transformations on PDT-style t-lemmas to make them look more TectoMT-like
(differentiating the various kinds of numerals, indefinite pronouns and pronominal adverbs)
using finite-state machinery.

This class requires the C<TLemmas.xfst> grammar file to be located in the same directory.  

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
