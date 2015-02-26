package Treex::Block::T2A::PT::CliticExceptions;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my %CHANGE = (
    "r-o" => "-lo",
    "r-a" => "-la",
    "r-os" => "-los",
    "r-as" => "-las",
    "s-o" => "-lo",
    "s-a" => "-la",
    "s-os" => "-los",
    "s-as" => "-las",
    "m-o" => "-no",
    "m-a" => "-na",
    "m-os" => "-nos",
    "m-as" => "-nas",
);

sub process_anode {

    my ( $self, $a_node ) = @_;
    return if $a_node->is_root or $a_node->get_parent->is_root;

    $a_node->get_parent->form =~ /^(.+)(.)([rsm])$/ or return;

    my ($stem, $vowel, $tense_marker) = ($1,$2,$3);

    my $current_clitic = $a_node->form;
    my $new_clitic = $CHANGE{"$tense_marker$current_clitic"};

    if ($new_clitic) {
        $vowel =~ s/a/á/;
        $vowel =~ s/e/ê/;

        $a_node->get_parent->set_form($stem.$vowel);
        $a_node->set_form($new_clitic);
    }

    return;


}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::PT::CliticExceptions

=head1 DESCRIPTION

Corrects portuguese clitics

=head1 AUTHORS

Zdeněk Žabokrtský <zaborktsky@ufal.mff.cuni.cz>

João A. Rodrigues <jrodrigues@di.fc.ul.pt>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by NLX Group, Universidade de Lisboa

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.



