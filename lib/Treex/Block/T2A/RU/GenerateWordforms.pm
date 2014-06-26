package Treex::Block::T2A::RU::GenerateWordforms;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::GenerateWordforms';

has 'generator_class' => ( is => 'rw', 
                              default=>'Treex::Tool::Lexicon::Generation::RUBigger');


sub process_anode  {
      my ($self, $anode) = @_;

      $self->SUPER::process_anode($anode);

      if ($anode->form eq "людей"){
            my $prev = $anode->get_prev_node;
            if (defined $prev
                and $prev->form =~ /^[0-9]+$/) {
                $anode->set_form("человек");
            }
      }

      my %abbrev=("миллионов"=>"млн",
                    "миллиардов"=>"млрд");
      if (exists $abbrev{$anode->form}) {
            my $prev = $anode->get_prev_node;
            my $next = $anode->get_next_node ;
            if (defined $prev
                    and $prev->form =~ /^([0-9]+,*)*$/
                and defined $next
                    and $next->form =~ /^\.$/
                ) {
                $anode->set_form($abbrev{$anode->form});
            }
     }

};

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::RU::GenerateWordforms

=item DESCRIPTION

Generates words for Russian.

It is basically Treex::Block::T2A::GenerateWordforms , just with
some hardcoded fixes.


=head1 AUTHORS

Karel Bilek <kb@karelbilek.com>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
