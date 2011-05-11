package Treex::Block::T2A::CS::TransformTLemmas;

use Moose;
use Treex::Core::Common;
use Treex::Tools::FSM::Foma;

extends 'Treex::Core::Block';

has '_foma' => ( is => 'rw', builder => '_init_foma' );

# Using TLemmas.xfst locate in the same directory as the source!
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
    $functor = $functor =~ m/^(TWHEN|THO|TSIN|TTILL|TFHL|THO|LOC|DIR1|DIR2|DIR3)$/ ? '+' . $functor : '';
    $functor =~ s/^\+ORIG$/+DIR1/;
    
    # 'jedno střídání' vs. 'jednou vypoví banka konto'
    if ($numer and $functor and $sempos =~ m/^n/){
        return;
    }

    if ( $old_lemma !~ /[0-9]/ and ( $indef or $numer or $old_lemma =~ /^(tady|tam|teď|potom|tehdy)$/ ) ) {
        $new_lemma = $self->_foma->down( $old_lemma . $numer . $indef . $functor );
    }

    # the old lemma was recognized by the grammar -> set new lemma
    if ( $new_lemma and ( $new_lemma ne '???' ) ) {
        log_info( 'FOMA:' . $old_lemma . $numer . $indef . $functor . ' -> ' . $new_lemma . '|' 
            . $tnode->get_deref_attr('a/lex.rf')->lemma );
        $tnode->set_t_lemma($new_lemma);
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 



=head1 DESCRIPTION


=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
