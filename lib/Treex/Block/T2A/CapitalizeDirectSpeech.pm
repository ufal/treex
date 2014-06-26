package Treex::Block::T2A::CapitalizeDirectSpeech;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'pre_opening_punct' => ( isa => 'Str', is => 'ro', default => ':' );
has 'opening_punct' => ( isa => 'Str', is => 'ro', default => '„«‹"\'“' );



sub process_anode {
    my ($self, $anode)=@_;

    my $prev = $anode->get_prev_node;
    if (!defined $prev) {
        return;
    }
    my $prev2 = $prev->get_prev_node;

    my $prev2_is_start;

    if (!defined $prev2) {
        $prev2_is_start=1;
    } else {
    
        my $pre_opening_punct = $self->pre_opening_punct;
        
        my $prev2_form = $prev2->form // $prev2->lemma;
        $prev2_is_start = ($prev2_form =~ /^[$pre_opening_punct]+$/);
    }
    
    my $opening_punct=$self->opening_punct;

    my $prev_form = $prev->form // $prev->lemma;
    if ($prev_form =~ /^[$opening_punct]+$/ and $prev2_is_start) {
        $anode->set_attr( 'form', ucfirst( $anode->form ) );
    }

}


1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::CapitalizeDirectSpeech

=head1 DESCRIPTION

Capitalize the first letter in a direct speech, detected
just by lemmas : and " .

It is detected only on "surface" level, without going to any trees.


=head1 AUTHORS 

Karel Bilek <kb@karelbilek.com>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
