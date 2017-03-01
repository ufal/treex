package Treex::Tool::Moses;
use Moose;
use Treex::Core::Common;
use utf8;

sub escape {
    my ($text) = @_;

    $text =~ s/\&/\&amp;/g;   # escape escape
    $text =~ s/\|/\&#124;/g;  # factor separator
    $text =~ s/\</\&lt;/g;    # xml
    $text =~ s/\>/\&gt;/g;    # xml
    $text =~ s/\'/\&apos;/g;  # xml
    $text =~ s/\"/\&quot;/g;  # xml
    $text =~ s/\[/\&#91;/g;   # syntax non-terminal
    $text =~ s/\]/\&#93;/g;   # syntax non-terminal

    return $text;
}

sub escape_anodes {
    my ($aroot) = @_;

    foreach my $anode ($aroot->get_descendants()) {
        $anode->set_form(escape($anode->form));
    }

    return;
}

1;

=head1 NAME 

Treex::Tool::Moses -- tools for Moses pre- and post-processing

=head1 DESCRIPTION

Bsed on Moses Sample Tokenizer Version 1.1
written by Pidong Wang, based on the code written by Josh Schroeder and Philipp Koehn
$Id: tokenizer.perl 915 2009-08-10 08:15:49Z philipp $

=head1 METHODS

=over

=item escape($text)

=item escape_anodes($aroot)

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>
Pidong Wang
Josh Schroeder
Philipp Koehn

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This file is licensed under the GNU Lesser General Public License version 2.1 or, at your option, any later version.

