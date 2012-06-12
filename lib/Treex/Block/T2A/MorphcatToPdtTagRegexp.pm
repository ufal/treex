package Treex::Block::T2A::MorphcatToPdtTagRegexp;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

my @CATEGORIES = qw(pos subpos gender number case possgender possnumber
    person tense grade negation voice reserve1 reserve2);

sub process_anode {
    my ( $self, $anode ) = @_;
    if ( $anode->get_attr(qw(morphcat)) ) {
        $anode->set_tag( join '',
                        map {$anode->get_attr("morphcat/$_")||'.'} @CATEGORIES);
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::MorphcatToPdtTagRegexp

=head1 DESCRIPTION

Serialize values of morphcat categories into a regular expression
for PDT-style POS tags.

=head1 AUTHOR

Zdenek Zabokrtsky

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
