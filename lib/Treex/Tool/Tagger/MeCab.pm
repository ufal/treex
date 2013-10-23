package Treex::Tool::Tagger::MeCab;
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

    $_ = <$reader>;

    # we store each line, which consists of wordform+features into @tokens as a string where each feature/wordform is separated by '\t'
    # other block should edit this output as needed
    # EOS marks end of sentence
    while ( $_ !~ "EOS" ) {
        
        # we don't want to substitute actual commas in the sentence
        $_ =~ s{^(.*),\t}{$1#comma\t};

        $_ =~ s{(.),}{$1\t}g;

        $_ =~ s{#comma}{,};

        push @tokens, $_;
        $_ = <$reader>;
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

Treex::Tools::Tagger::MeCab - perl wrapper for C implemented japanese morphological analyzer MeCab

=head1 DESCRIPTION

This is a Perl wrapper for MeCab tagger and tokenizer implemented in C++.
Tagger homepage: http://mecab.googlecode.com/svn/trunk/mecab/doc/index.html
Generates string of features (first one is wordform) for each token generated. Returns array of tokens for further use.

=back

=head1 AUTHORS

Dusan Varis

=head1 COPYRIGHT AND LICENSE

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

