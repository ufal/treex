package Treex::Tool::Tagger::MeCab;

use strict;
use warnings;

use Moose;
use Treex::Core::Common;
use Treex::Core::Config;
use Treex::Tool::ProcessUtils;
use Treex::Core::Resource;

sub BUILD {
    my ($self) = @_;

    # TODO find architecture independent solution
    my $bin_path = require_file_from_share(
        'installed_tools/tagger/MeCab/bin/mecab',
    	ref($self)
    );
     
    my $cmd = "$bin_path".' 2>/dev/null';

    # start MeCab tagger
    my ( $reader, $writer, $pid ) = Treex::Tool::ProcessUtils::bipipe( $cmd, ':encoding(utf-8)' );

    $self->{reader} = $reader;
    $self->{writer} = $writer;
    $self->{pid}    = $pid;

    return;
}

sub process_sentence {
    my ( $self, $sentence ) = @_;

    my @tokens;
    my $writer = $self->{writer};
    my $reader = $self->{reader};

    print $writer $sentence."\n";

    my $line = <$reader>;

    # we store each line, which consists of wordform+features into @tokens as a string where each feature/wordform is separated by '\t'
    # other block should edit this output as needed
    # EOS marks end of sentence
    while ( $line !~ "EOS" ) {
       
        log_fatal("Unitialized line (perhaps MeCab was not initialized correctly).") if (!defined $line); # even with empty string input we should get at least "EOS" line in output, otherwise the tagger wasn't correctly initialized
 
        # we don't want to substitute actual commas in the sentence
        $line =~ s{^(.*),\t}{$1#comma\t};

        $line =~ s{(.),}{$1\t}g;

        $line =~ s{#comma}{,};

        push @tokens, $line;
        $line = <$reader>;
    }

    return @tokens;

}

# ----------------- cleaning up ------------------
# # TODO : cleanup

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Tool::Tagger::MeCab - perl wrapper for C implemented japanese morphological analyzer MeCab

=head1 SYNOPSIS

 use Treex::Tool::Tagger::MeCab;
 my $tagger = Treex::Tool::Tagger::MeCab->new();
 my $sentence = qw(わたしは日本語を話します);
 my @tokens = $tagger->process_sentence($sentence);

=head1 DESCRIPTION

This is a Perl wrapper for MeCab tagger and tokenizer implemented in C++.
Generates string of features (first one is wordform) for each token generated. Returns array of tokens for further use.

=head1 INSTALLATION

Before installing MeCab, make sure you have properly installed the Treex-Core package (see L<Treex Installation|http://ufal.mff.cuni.cz/treex/install.html>), since it is prerequisite for this module anyway.
After installing Treex-Core you can install MeCab using this L<Makefile|https://svn.ms.mff.cuni.cz/svn/tectomt_devel/trunk/install/tool_installation/MeCab/Makefile> (username "public" passwd "public"). Prior to runing the makefile, you must set the enviromental variable "$TMT_ROOT" to the location of your .treex directory.

You can also install MeCab manually but then you must link the installation directory to the ${TMT_ROOT}/share/installed_tools/tagger/MeCab/ (location within Treex share), otherwise the modules will not be able to use the program.

=head1 METHODS

=over

=item @tokens = $tagger->process_sentence($sentence);

Returns list of "tokens" for the tokenized input with its morphological categories each separated by \t.

=back

=head1 SEE ALSO

L<MeCab Home Page|http://mecab.googlecode.com/svn/trunk/mecab/doc/index.html> 

=head1 AUTHOR

Dušan Variš <dvaris@seznam.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
