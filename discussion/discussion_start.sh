#!/bin/bash
# ============================================================
# Discussion System Startup Script
# 複数AIモデル討論システム起動スクリプト
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DISCUSSION_DIR="$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SESSION_NAME="discussion"

# ============================================================
# Functions
# ============================================================

print_banner() {
    echo -e "${PURPLE}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║     🎭 Multi-Model Discussion System 🎭                       ║
║                                                               ║
║     Claude × Gemini × Codex                                   ║
║     ブレインストーミング・討論プラットフォーム                     ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

check_requirements() {
    echo -e "${BLUE}📋 Requirements check...${NC}"

    # Check tmux
    if ! command -v tmux &> /dev/null; then
        echo -e "${RED}❌ tmux is not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ tmux${NC}"

    # Check claude CLI
    if ! command -v claude &> /dev/null; then
        echo -e "${RED}❌ claude CLI is not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ claude CLI${NC}"

    echo ""
}

cleanup_session() {
    echo -e "${YELLOW}🧹 Cleaning up existing session...${NC}"
    tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true
    sleep 1
}

reset_queue_files() {
    echo -e "${YELLOW}📝 Resetting queue files...${NC}"

    # Reset topic
    cat > "$DISCUSSION_DIR/queue/topic.yaml" << 'EOF'
# Discussion Topic
topic_id: null
title: null
description: null
context: null
started_at: null
current_phase: null
current_round: 0
status: idle
initiated_by: user
instructions: null
EOF

    # Reset consensus
    cat > "$DISCUSSION_DIR/queue/consensus.yaml" << 'EOF'
# Consensus Tracking
topic_id: null
status: none
agreements: []
disagreements: []
conclusion: null
action_items: []
EOF

    # Clear turns directory
    rm -f "$DISCUSSION_DIR/queue/turns/"*.yaml 2>/dev/null || true
    rm -f "$DISCUSSION_DIR/queue/responses/"*.yaml 2>/dev/null || true

    echo -e "${GREEN}✓ Queue files reset${NC}"
}

init_visualizer_dashboard() {
    echo -e "${YELLOW}📊 Initializing visualizer dashboard...${NC}"

    cat > "$DISCUSSION_DIR/visualizer/dashboard.md" << EOF
# 🎭 討論ダッシュボード

**最終更新**: $(date '+%Y-%m-%d %H:%M:%S')

## 📌 現在のトピック

\`\`\`
待機中...
\`\`\`

## 🔄 討論の流れ

| ラウンド | フェーズ | 発言者 | サマリ |
|---------|---------|--------|--------|
| - | - | - | 討論開始待ち |

## 💡 各モデルの立場

### 🟣 Claude
> 待機中

### 🟢 Gemini
> 待機中

### 🟡 Codex
> 待機中

## 🤝 合意状況

**ステータス**: 討論未開始

### 合意点
- なし

### 相違点
- なし

## 📝 結論

*討論完了後に更新されます*

---
*Visualizer によって自動更新*
EOF

    echo -e "${GREEN}✓ Dashboard initialized${NC}"
}

create_tmux_session() {
    echo -e "${BLUE}🖥️  Creating tmux session...${NC}"

    # Create new session with first pane (Claude)
    tmux new-session -d -s "$SESSION_NAME" -n "arena" -x 200 -y 50

    # Split into 2x2 grid
    # First split horizontally (left | right)
    tmux split-window -h -t "$SESSION_NAME:0"

    # Split left column vertically (Claude on top, Codex below)
    tmux split-window -v -t "$SESSION_NAME:0.0"

    # Split right column vertically (Gemini on top, Visualizer below)
    tmux split-window -v -t "$SESSION_NAME:0.2"

    # Now we have:
    # Pane 0: Top-left (Claude)
    # Pane 1: Bottom-left (Codex)
    # Pane 2: Top-right (Gemini)
    # Pane 3: Bottom-right (Visualizer)

    # Set pane titles
    tmux select-pane -t "$SESSION_NAME:0.0" -T "claude"
    tmux select-pane -t "$SESSION_NAME:0.1" -T "codex"
    tmux select-pane -t "$SESSION_NAME:0.2" -T "gemini"
    tmux select-pane -t "$SESSION_NAME:0.3" -T "visualizer"

    # Enable pane borders with titles
    tmux set-option -t "$SESSION_NAME" pane-border-status top
    tmux set-option -t "$SESSION_NAME" pane-border-format " #{pane_title} "

    echo -e "${GREEN}✓ Tmux session created${NC}"
    echo ""
    echo -e "${CYAN}Layout:${NC}"
    echo "┌─────────────────┬─────────────────┐"
    echo "│   🟣 Claude     │   🟢 Gemini     │"
    echo "│   (Pane 0)      │   (Pane 2)      │"
    echo "├─────────────────┼─────────────────┤"
    echo "│   🟡 Codex      │   📊 Visualizer │"
    echo "│   (Pane 1)      │   (Pane 3)      │"
    echo "└─────────────────┴─────────────────┘"
    echo ""
}

setup_pane_prompts() {
    echo -e "${BLUE}🎨 Setting up pane prompts...${NC}"

    # Claude (Purple)
    tmux send-keys -t "$SESSION_NAME:0.0" "export PS1='\\[\\033[1;35m\\][Claude]\\[\\033[0m\\] \\w\\$ '" Enter
    tmux send-keys -t "$SESSION_NAME:0.0" "cd $DISCUSSION_DIR" Enter
    tmux send-keys -t "$SESSION_NAME:0.0" "clear" Enter

    # Gemini (Green)
    tmux send-keys -t "$SESSION_NAME:0.2" "export PS1='\\[\\033[1;32m\\][Gemini]\\[\\033[0m\\] \\w\\$ '" Enter
    tmux send-keys -t "$SESSION_NAME:0.2" "cd $DISCUSSION_DIR" Enter
    tmux send-keys -t "$SESSION_NAME:0.2" "clear" Enter

    # Codex (Yellow)
    tmux send-keys -t "$SESSION_NAME:0.1" "export PS1='\\[\\033[1;33m\\][Codex]\\[\\033[0m\\] \\w\\$ '" Enter
    tmux send-keys -t "$SESSION_NAME:0.1" "cd $DISCUSSION_DIR" Enter
    tmux send-keys -t "$SESSION_NAME:0.1" "clear" Enter

    # Visualizer (Cyan)
    tmux send-keys -t "$SESSION_NAME:0.3" "export PS1='\\[\\033[1;36m\\][Visualizer]\\[\\033[0m\\] \\w\\$ '" Enter
    tmux send-keys -t "$SESSION_NAME:0.3" "cd $DISCUSSION_DIR" Enter
    tmux send-keys -t "$SESSION_NAME:0.3" "clear" Enter

    sleep 1
    echo -e "${GREEN}✓ Pane prompts configured${NC}"
}

launch_agents() {
    echo -e "${BLUE}🚀 Launching AI agents...${NC}"

    # Launch Claude agent
    echo -e "  ${PURPLE}Starting Claude...${NC}"
    tmux send-keys -t "$SESSION_NAME:0.0" "claude --dangerously-skip-permissions" Enter
    sleep 2

    # Launch Gemini agent (using claude CLI with different instruction)
    echo -e "  ${GREEN}Starting Gemini...${NC}"
    tmux send-keys -t "$SESSION_NAME:0.2" "claude --dangerously-skip-permissions" Enter
    sleep 2

    # Launch Codex agent
    echo -e "  ${YELLOW}Starting Codex...${NC}"
    tmux send-keys -t "$SESSION_NAME:0.1" "claude --dangerously-skip-permissions" Enter
    sleep 2

    # Launch Visualizer agent
    echo -e "  ${CYAN}Starting Visualizer...${NC}"
    tmux send-keys -t "$SESSION_NAME:0.3" "claude --dangerously-skip-permissions" Enter
    sleep 2

    echo -e "${GREEN}✓ All agents launched${NC}"
}

send_instructions() {
    echo -e "${BLUE}📜 Sending instructions to agents...${NC}"

    sleep 3  # Wait for Claude CLI to initialize

    # Send instruction to Claude
    echo -e "  ${PURPLE}Instructing Claude...${NC}"
    CLAUDE_INST=$(cat "$DISCUSSION_DIR/instructions/claude.md" 2>/dev/null || echo "You are Claude, a discussion participant. Read instructions/claude.md for details.")
    tmux send-keys -t "$SESSION_NAME:0.0" "$CLAUDE_INST"
    sleep 0.5
    tmux send-keys -t "$SESSION_NAME:0.0" Enter

    # Send instruction to Gemini
    echo -e "  ${GREEN}Instructing Gemini...${NC}"
    GEMINI_INST=$(cat "$DISCUSSION_DIR/instructions/gemini.md" 2>/dev/null || echo "You are Gemini, a discussion participant. Read instructions/gemini.md for details.")
    tmux send-keys -t "$SESSION_NAME:0.2" "$GEMINI_INST"
    sleep 0.5
    tmux send-keys -t "$SESSION_NAME:0.2" Enter

    # Send instruction to Codex
    echo -e "  ${YELLOW}Instructing Codex...${NC}"
    CODEX_INST=$(cat "$DISCUSSION_DIR/instructions/codex.md" 2>/dev/null || echo "You are Codex, a discussion participant. Read instructions/codex.md for details.")
    tmux send-keys -t "$SESSION_NAME:0.1" "$CODEX_INST"
    sleep 0.5
    tmux send-keys -t "$SESSION_NAME:0.1" Enter

    # Send instruction to Visualizer
    echo -e "  ${CYAN}Instructing Visualizer...${NC}"
    VIS_INST=$(cat "$DISCUSSION_DIR/instructions/visualizer.md" 2>/dev/null || echo "You are the Visualizer. Read instructions/visualizer.md for details.")
    tmux send-keys -t "$SESSION_NAME:0.3" "$VIS_INST"
    sleep 0.5
    tmux send-keys -t "$SESSION_NAME:0.3" Enter

    echo -e "${GREEN}✓ Instructions sent${NC}"
}

print_usage() {
    echo -e "${CYAN}"
    cat << 'EOF'

════════════════════════════════════════════════════════════════
                         使い方
════════════════════════════════════════════════════════════════

1. 討論セッションにアタッチ:
   $ tmux attach -t discussion

2. ペイン間移動:
   Ctrl+b → 矢印キー

3. 討論トピックを設定:
   Visualizerペインで:
   "〇〇について討論を開始してください"

4. セッション終了:
   $ tmux kill-session -t discussion

════════════════════════════════════════════════════════════════
EOF
    echo -e "${NC}"
}

# ============================================================
# Main
# ============================================================

main() {
    print_banner
    check_requirements
    cleanup_session
    reset_queue_files
    init_visualizer_dashboard
    create_tmux_session
    setup_pane_prompts
    launch_agents
    send_instructions
    print_usage

    echo -e "${GREEN}🎉 Discussion system is ready!${NC}"
    echo -e "${YELLOW}Run: tmux attach -t discussion${NC}"
}

main "$@"
