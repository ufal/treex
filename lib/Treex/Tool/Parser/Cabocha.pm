package Treex::Tool::Parser::Cabocha;

use strict;
use warnings;

use Moose;
use Treex::Core::Common;
use Treex::Core::Config;
use Treex::Tool::ProcessUtils;
use Treex::Core::Resource;

has model_dir => ( isa => 'Str', is => 'rw', required => 1 );

sub BUILD {
    my ($self) = @_;

    # TODO find architecture independent solution
    my $bin_path = require_file_from_share(
        'installed_tools/parser/cabocha/bin/cabocha',
        ref($self)
    );
 
    #TODO: fix setting up of the model_dir via Treex (see W2A::JA::ParseCabocha)
    # right now only way of selecting model_dir is via configuring Cabocha
    # my $model_dir = $self->model_dir;
    # in the worst case, it will use default model

    my $cmd = "$bin_path".' -I1 -f1';
 
    # start JDEPP parser
    my ( $reader, $writer, $pid ) = Treex::Tool::ProcessUtils::bipipe( $cmd, ':encoding(utf-8)' );    

    $self->{reader} = $reader;
    $self->{writer} = $writer;
    $self->{pid}    = $pid;

    return;
}

sub parse_sentence {

    my ( $self, $forms_rf, $tags_rf ) = @_;

    if ( ref($forms_rf) ne "ARRAY" or ref($tags_rf) ne "ARRAY" ) {
        log_fatal('Both arguments must be array references.');
    }

    if ( $#{$forms_rf} != $#{$tags_rf} or @$forms_rf == 0 ) {
        log_warn "FORMS: @$forms_rf\n";
        log_warn "TAGS:  @$tags_rf\n";
        log_fatal('Both arguments must be references to nonempty arrays of equal length.');
    }

    if ( my @ret = grep { $_ =~ /^\s+$/ } ( @{$forms_rf}, @{$tags_rf} ) ) {
        log_debug("@ret");
        log_fatal('Elements of argument arrays must not be empty and must not contain white-space characters');
    }

    my @parents;
    my $input = "";
    my $writer = $self->{writer};
    my $reader = $self->{reader};

    foreach my $form ( @$forms_rf ) {
        my $tag = shift @$tags_rf;
        $tag =~ s{-}{,}g;
        $input .= $form . "\t" . $tag . "\n";
    }
    $input .= "EOS\n";  

    print $writer $input;

    my $line = <$reader>;
    
 
    # Cabocha uses different token ordering than Treex, because it creates "bunsetsus" (phrases) out of multiple tokens (parsing is done on these "bunsetsus")
    # Cabocha does not separate verbs from "modals" into 2 separate phrases, we want to take care of this in this block too
    # e.g. "買っておきました" -> "買って" "おきました"

    my %bun_heads;      # we mark for each bunsetsu, which node should act as a parent for its "child-bunsetsu"
    my $current_token = 0;
    my $verb_token = -1; # when we find a verb inside bunsetsu, following tokens from that bunsetsu should be dependent on it

    my $bun = 0;
    my $parent = 0;
    while ( $line !~ "EOS") {

        log_fatal("Unitialized line (perhaps Cabocha was not initialized correctly).") if (!defined $line);        

        next if $line =~ /^#|EOS/;  # skip uninteresting lines

        if ( $line =~ /^\*/ ) {
            $verb_token = -1;
            $line =~ s{^\*\s+}{}; 
            ($bun, $parent) = split / /, $line;
            $bun_heads{ $bun } = $current_token + 1;
            $parent =~ s{D}{};

            # since we still do not know which node in treex representation corresponds to the parent bunsetsu we note it with its negative value
            $parents[ $current_token ] = $parent * -1; 

            # set the parent of the "root"
            $parents[ $current_token ] = 0 if( $parent == -1 ); 
        }
        
        # Japanese is head-final language, so (most of the times) inside bunsetsu, every token is dependent on the following token
        # exceptions should be handled after parsing
        else {
            if ( !(defined $parents[ $current_token ] ) ) {
              if($verb_token < 0) {
                $parents[ $current_token ] = $parents[ $current_token - 1];
                $parents[ $current_token - 1] = $current_token + 1;  
                $bun_heads{ $bun } = $current_token + 1;
              }
              # if there is a noun following a verb within bunsetsu, we "split" the bunsetsu
              elsif ($line =~ /\t名詞,非自立/) {
                $bun = $bun + 0.5;
                $bun_heads{ $bun } = $current_token + 1;
                $parents[ $current_token ] = $parents[ $current_token - 1];
                $parents[ $current_token - 1] = $bun * -1;
                $verb_token = -1;
              }
              else {
                # Only auxiliaries follow verbs most of the times
                $parents[ $current_token ] = $verb_token;
              }
            }
            # if the current token is verb, the following tokens should be its children
            $verb_token = ($current_token + 1) if ($line =~ /\t動詞/ && $line !~ /接尾/);

            $current_token++;
        }
        $line = <$reader>;
    } 

    # now we fix the parents of each bunsetsu so they point at their correct treex representants (the parents with negative value)
    my $i = 0;
    while ( defined $parents[ $i ] ) {
        if ( $parents[ $i ] < 0 ) {
            # based on the bunsetsu numbering, we assign real parent node
            my $parent = $bun_heads{ $parents[ $i ] * -1 };
            $parents[ $i ] = $parent;
        }
        $i++;  
    }
    
    return \@parents;

}

# ----------------- cleaning up ------------------
# TODO : cleanup

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::Cabocha - perl wrapper for C implemented japanese dependency parser Cabocha

=head1 SYNOPSIS

 use Treex::Tool::Parser::Cabocha;
 my $model_dir; # default 'data/models/parser/cabocha/model'
 my $parser = Treex::Tool::Parser::Cabocha->new( model_dir => $model_dir );
 my @tokens = qw(わたし は 日本語 を 話し ます);
 my @tags = qw(名詞-代名詞-一般-* 助詞-係助詞-*-* 名詞-一般-*-* 助詞-格助詞-一般-* 動詞-自立-*-* 助動詞-*-*-*); # IPADIC tagset
 my $parents_rf = $parser->parse_sentence( \@tokens, \@tags );

=head1 DESCRIPTION

This is a Perl wrapper for Cabocha parser implemented in C.
This parser works with tokens and POS tags generated by MeCab tagger for dependency parsing. Tokens are grouped together into "bunstetsu", then parsing is performed on these bunsetsu. Simple dependencies between each tokens are generated later in this module.

=head1 INSTALLATION

Before installing Cabocha, make sure you have properly installed the Treex-Core package (see L<Treex Installation|http://ufal.mff.cuni.cz/treex/install.html>), since it is prerequisite for this module anyway.
After installing Treex-Core you can install Cabocha using this L<Makefile|https://svn.ms.mff.cuni.cz/svn/tectomt_devel/trunk/install/tool_installation/Cabocha/Makefile> (username "public" passwd "public"). Prior to runing the makefile, you must set the enviromental variable "$TMT_ROOT" to the location of your .treex directory.

You can also install Cabocha manually but then you must link the installation directory to the ${TMT_ROOT}/share/installed_tools/parser/Cabocha/ (location within Treex share), otherwise the modules will not be able to use the program.

=head1 METHODS

=over

=item $parents_rf = $parser->parse_sentence( \@tokens, \@tags );

Returns reference to the list of parent nodes for input tokens.

=back

=head1 SEE ALSO

L<Cabocha Home Page|https://code.google.com/p/cabocha/> for more info on Cabocha parser

=head1 AUTHOR

Dušan Variš <dvaris@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
