package Treex::Block::W2A::EN::PreferImperatives;

use strict;
use warnings;
use utf8;
use Moose;
use Treex::Core::Common;
use LX::Data::EN;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;

    my $old_tag = $anode->tag;
    my $ord = $anode->ord;
    if ($old_tag =~ /^(JJ|NN)$/ && $LX::Data::EN::VB_Form{lc $anode->form}
            && $anode->ord == 1) {
        $anode->set_tag("VB");
        print STDERR "W2A::EN::PreferImperatives: changed ".$anode->form."/".$old_tag." to VB\n";
        print STDERR "W2A::EN::PreferImperatives: ".$anode->get_root->get_zone->sentence."\n";
    }
    return 1;
}


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::EN::PreferImperatives

=head1 DESCRIPTION



=head1 AUTHORS

Luís Gomes <luis.gomes@di.fc.ul.pt>, <luismsgomes@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by NLX Group, Universidade de Lisboa

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
