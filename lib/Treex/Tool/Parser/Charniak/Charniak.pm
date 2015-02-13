package Treex::Tool::Parser::Charniak::Charniak;
use Moose;
use MooseX::FollowPBP;
use Treex::Core::Log;
use Treex::Tool::Parser::Charniak::Node;
use Treex::Tool::ProcessUtils;
use IPC::Open2;
use IPC::Open3;
use IO::Handle;
use Treex::Core::Common;

my $tmp_input = 'test';
my $bindir    = "/home/green/tectomt/personal/green/tools/reranking-parser";
my $command   = "$bindir/parse.sh $tmp_input";

my @results;
my $tmp_file;

sub BUILD {
    my ($self) = @_;
    log_fatal "Missing $bindir\n" if !-d $bindir;
    my $rand = rand();
    $tmp_file = "$bindir/temporary-$rand.txt";
    my $runparser_command = "sh parse.sh $tmp_file";

    my ( $reader, $writer, $pid ) = Treex::Tool::ProcessUtils::bipipe("cd $bindir; $runparser_command ");
    $self->{tntreader} = $reader;
    $self->{tntwriter} = $writer;
    $self->{tntpid}    = $pid;

    bless $self;
}

sub string_output {

    my ( $self, @tokens ) = @_;

    # creating a temporary file - parser input
    # my $tmp_file = "$bindir/temporary-$self.txt";
    #  log_info 'Storing the sentence into temporary file: $tmp_file';

    my $string = "<s> " . ( join ' ', @tokens ) . " </s>";
    $string =~ s/''/"/g;
    $string =~ s/``/"/g;
    open my $INPUT, '>:utf8', $tmp_file or log_fatal $!;
    print $INPUT $string;
    close $INPUT;
    my $tntwr = $self->{tntwriter};
    my $tntrd = $self->{tntreader};
    my $got   = <$tntrd>;

}

sub document_output {

    my ( $self, @sentences ) = @_;

    my $counter = 0;
    foreach my $sentence (@sentences) {
        my $string = $sentence;
        $string =~ s/''/"/g;
        $string =~ s/``/"/g;
        $sentences[$counter] = $string;

        #print "$counter \t $string \n";
        $counter++;
    }

    open my $INPUT, '>:utf8', $tmp_file or log_fatal $!;
    print $INPUT join( "", @sentences );
    close $INPUT;

    my $tntwr = $self->{tntwriter};
    my $tntrd = $self->{tntreader};

    # my $got = <$tntrd>;

    #print  "output: \n";
    my $got = <$tntrd>;

    #print "\n";
}

sub parse {
    my ( $self, @tokens_rf ) = @_;
    _make_phrase_structure( string_output( $self, @tokens_rf ) );

}

sub parse_document {
    my ( $self, @tokens_rf ) = @_;
    my $parsed = document_output( $self, @tokens_rf );
    print "parsed" . $parsed;

    #_make_phrase_structure(string_output($self,@tokens_rf));
    #loop through sentences (start with S1) and send to _make_phrase_structure
}

sub _make_phrase_structure {
    my ($parser_output) = @_;

    #print $parser_output;
    my @tree       = ();
    my @final_tree = ();

    my @tags = split( " ", $parser_output );

    foreach my $tag (@tags) {

        # opening a node
        if ( $tag =~ /[\(\[\{]/ ) {
            substr( $tag, index( $tag, "\(" ), 1, "" );
            my $node = Treex::Tool::Parser::Charniak::Node->new( term => $tag );
            push( @tree, $node );

            #   print "added $tag\n";
        }

        # closing the node
        elsif ( $tag =~ /[\)\]\}]/ ) {
            my $parentCount = 0;
            while ( $tag =~ /[\)\]\}]/ ) {
                $parentCount++;
                substr( $tag, index( $tag, "\)" ), 1, "" );
            }
            my $node = Treex::Tool::Parser::Charniak::Node->new( term => $tag );

            push( @tree,       $node );
            push( @final_tree, $node );

            my $i = 0;

            while ( $i < $parentCount ) {
                $node = pop(@tree);

                my $parent = pop(@tree);

                push( @final_tree, $node );
                $parent->add_child($node);

                #print "Added ".$node->get_type()." to ".$parent->get_type()." \n";
                push( @tree, $parent );
                $i++;
            }

            #add link to parent top branch) nodes where the parent is comprised of multiple sub branches
            $node = pop(@tree);
            push( @final_tree, $node );
            my $topBranch = pop(@tree);
            if ($topBranch) {
                $topBranch->add_child($node);

                #		print "Added ".$node->get_type()." to ".$topBranch->get_type()." \n";
                push( @tree, $topBranch );
            }
        }

    }

    return pop @final_tree;

}

1;

__END__


